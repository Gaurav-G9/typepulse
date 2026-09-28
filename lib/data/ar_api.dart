import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Client for AR Typing Platform backend (Heroku API used by artypingplatform.com).
///
/// Endpoints discovered from the public Next.js bundles:
/// - POST /jwt/create/          {email, password} → {access, refresh}
/// - POST /jwt/refresh/         {refresh} → {access}
/// - POST /logout/              {refresh} + JWT
/// - GET  /learning/typedPassages/?page=&page_size=
/// - GET  /learning/memberTypingStats/
/// - GET  /learning/students/profile/
///
/// Tokens are stored per [accountId] so multiple AR logins can coexist on one device.
class ArTypingApi {
  static const baseUrl =
      'https://artypingplatform-efb5438ddb1b.herokuapp.com/api/v1';
  static const siteUrl = 'https://www.artypingplatform.com';

  /// Network calls never hang forever (important for background isolates).
  static const requestTimeout = Duration(seconds: 25);

  // Legacy single-account keys (migrated on first load).
  static const _kLegacyAccess = 'ar_access_token';
  static const _kLegacyRefresh = 'ar_refresh_token';
  static const _kLegacyEmail = 'ar_email';

  final FlutterSecureStorage _secure;
  final http.Client _http;

  String? accountId;
  String? accessToken;
  String? refreshToken;
  String? email;

  /// Shared in-flight refresh so parallel 401s trigger a single token refresh.
  Future<_RefreshOutcome>? _refreshInFlight;

  ArTypingApi({
    FlutterSecureStorage? secure,
    http.Client? httpClient,
  })  : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _http = httpClient ?? http.Client();

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  String _accessKey(String id) => 'ar_access_$id';
  String _refreshKey(String id) => 'ar_refresh_$id';

  Future<void> loadAccount(String id, {String? emailHint}) async {
    accountId = id;
    email = emailHint;
    try {
      accessToken = await _secure.read(key: _accessKey(id));
      refreshToken = await _secure.read(key: _refreshKey(id));
    } catch (_) {
      // Keystore can be unreadable after a backup restore / OS upgrade;
      // treat as signed out instead of crashing the app.
      accessToken = null;
      refreshToken = null;
    }
  }

  /// Migrate pre-multi-account tokens into the given [accountId].
  Future<bool> migrateLegacyTokens(String accountId, String email) async {
    final access = await _secure.read(key: _kLegacyAccess);
    final refresh = await _secure.read(key: _kLegacyRefresh);
    if (access == null || access.isEmpty) return false;
    this.accountId = accountId;
    this.email = email;
    accessToken = access;
    refreshToken = refresh;
    await _persist();
    await _secure.delete(key: _kLegacyAccess);
    await _secure.delete(key: _kLegacyRefresh);
    await _secure.delete(key: _kLegacyEmail);
    return true;
  }

  Future<Map<String, String?>> readLegacyTokens() async {
    try {
      return {
        'access': await _secure.read(key: _kLegacyAccess),
        'refresh': await _secure.read(key: _kLegacyRefresh),
        'email': await _secure.read(key: _kLegacyEmail),
      };
    } catch (_) {
      return const {'access': null, 'refresh': null, 'email': null};
    }
  }

  Future<void> _persist() async {
    final id = accountId;
    if (id == null) return;
    if (accessToken != null) {
      await _secure.write(key: _accessKey(id), value: accessToken!);
    } else {
      await _secure.delete(key: _accessKey(id));
    }
    if (refreshToken != null) {
      await _secure.write(key: _refreshKey(id), value: refreshToken!);
    } else {
      await _secure.delete(key: _refreshKey(id));
    }
  }

  /// Shown when AR Typing stops accepting this device's sign-in.
  static const sessionEndedMessage =
      'AR Typing ended this sign-in — usually because the same account '
      'signed in on another device or browser. Sign in again to keep syncing.';

  /// Adopt tokens another isolate (Workmanager / background service) has
  /// refreshed and saved since we loaded ours. Returns true if they changed.
  Future<bool> _adoptStoredTokens() async {
    final id = accountId;
    if (id == null) return false;
    try {
      final access = await _secure.read(key: _accessKey(id));
      final refresh = await _secure.read(key: _refreshKey(id));
      if (access != null && access.isNotEmpty && access != accessToken) {
        accessToken = access;
        refreshToken = refresh;
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> clearSession() async {
    final id = accountId;
    accessToken = null;
    refreshToken = null;
    if (id != null) {
      await _secure.delete(key: _accessKey(id));
      await _secure.delete(key: _refreshKey(id));
    }
  }

  /// Delete tokens for an account that is not currently loaded.
  Future<void> deleteTokensFor(String id) async {
    await _secure.delete(key: _accessKey(id));
    await _secure.delete(key: _refreshKey(id));
    if (accountId == id) {
      accessToken = null;
      refreshToken = null;
      email = null;
      accountId = null;
    }
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'JWT $accessToken',
      };

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String accountId,
  }) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/jwt/create/'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(requestTimeout);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = _tryDecode(res.body);
      final body =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      this.accountId = accountId;
      accessToken = body['access'] as String?;
      refreshToken = body['refresh'] as String?;
      this.email = email.trim();
      if (accessToken == null || accessToken!.isEmpty) {
        throw ArApiException('Login succeeded but no access token returned.');
      }
      await _persist();
      return body;
    }

    final detail = _errorDetail(res);
    if (res.statusCode == 401) {
      throw ArApiException(
        'Invalid email or password. CAPS LOCK should be off — passwords are case sensitive.',
        statusCode: 401,
      );
    }
    throw ArApiException(detail, statusCode: res.statusCode);
  }

  Future<bool> refreshAccessToken() async =>
      (await _refresh()) == _RefreshOutcome.ok;

  Future<_RefreshOutcome> _refresh() {
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<_RefreshOutcome> _doRefresh() async {
    // The app and its background sync run in separate isolates with their
    // own copy of the tokens. If the other one already refreshed (and the
    // server rotated the refresh token), use its newer tokens instead of
    // spending our stale refresh token — which would be rejected.
    if (await _adoptStoredTokens()) return _RefreshOutcome.ok;
    if (refreshToken == null || refreshToken!.isEmpty) {
      return _RefreshOutcome.rejected;
    }
    final sentRefresh = refreshToken;
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/jwt/refresh/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(requestTimeout);
    } catch (_) {
      // Offline / timeout: keep tokens, try again next sync.
      return _RefreshOutcome.failed;
    }
    if (res.statusCode == 200) {
      final body = _tryDecode(res.body);
      final access = body is Map ? body['access'] as String? : null;
      if (access == null || access.isEmpty) return _RefreshOutcome.failed;
      accessToken = access;
      // SimpleJWT with ROTATE_REFRESH_TOKENS returns a new refresh token too.
      final rotated = body['refresh'];
      if (rotated is String && rotated.isNotEmpty) refreshToken = rotated;
      await _persist();
      return _RefreshOutcome.ok;
    }
    if (res.statusCode == 400 || res.statusCode == 401) {
      // Another isolate may have rotated the token while we were asking.
      if (await _adoptStoredTokens() && refreshToken != sentRefresh) {
        return _RefreshOutcome.ok;
      }
      // Refresh token expired/blacklisted — clear so the UI asks to sign in.
      await clearSession();
      return _RefreshOutcome.rejected;
    }
    // 5xx / Heroku waking up: transient, keep the session.
    return _RefreshOutcome.failed;
  }

  Future<void> logoutRemote() async {
    try {
      if (accessToken != null && refreshToken != null) {
        await _http
            .post(
              Uri.parse('$baseUrl/logout/'),
              headers: _authHeaders,
              body: jsonEncode({'refresh': refreshToken}),
            )
            .timeout(requestTimeout);
      }
    } catch (_) {
      // Best-effort remote logout.
    }
    await clearSession();
  }

  Future<http.Response> _authedGet(Uri uri, {Duration? timeout}) async {
    final limit = timeout ?? requestTimeout;
    final sentWith = accessToken;
    var res = await _http.get(uri, headers: _authHeaders).timeout(limit);
    if (res.statusCode == 401) {
      // Another request may already have refreshed the token.
      final outcome = accessToken != sentWith && accessToken != null
          ? _RefreshOutcome.ok
          : await _refresh();
      switch (outcome) {
        case _RefreshOutcome.ok:
          res = await _http.get(uri, headers: _authHeaders).timeout(limit);
          if (res.statusCode == 401) {
            // Even a freshly refreshed token is refused: the server has ended
            // this session (e.g. the account signed in elsewhere). Don't keep
            // failing silently on every sync — ask the user to sign in again.
            await clearSession();
            throw ArApiException(
              sessionEndedMessage,
              statusCode: 401,
              needsReauth: true,
            );
          }
        case _RefreshOutcome.rejected:
          throw ArApiException(
            sessionEndedMessage,
            statusCode: 401,
            needsReauth: true,
          );
        case _RefreshOutcome.failed:
          throw ArApiException(
            'Could not refresh your AR Typing session. Check your connection.',
            statusCode: 401,
          );
      }
    }
    return res;
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static ArHistoryPage _parseHistoryPage(http.Response res) {
    final body = _tryDecode(res.body);
    if (body is List) {
      return ArHistoryPage(
        results: body.whereType<Map<String, dynamic>>().toList(),
        count: body.length,
        next: null,
      );
    }
    if (body is! Map<String, dynamic>) {
      throw ArApiException('Unexpected response from AR Typing.',
          statusCode: res.statusCode);
    }
    final results = (body['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final next = body['next'];
    return ArHistoryPage(
      results: results,
      count: _asInt(body['count']) ?? results.length,
      next: next is String && next.isNotEmpty ? next : null,
    );
  }

  static void _checkHistoryStatus(http.Response res) {
    if (res.statusCode == 403) {
      throw ArApiException(
        'Free Mode limit or plan restriction on typing history. Upgrade on AR Typing if needed.',
        statusCode: 403,
        freeMode: true,
      );
    }
    if (res.statusCode != 200) {
      throw ArApiException(_errorDetail(res), statusCode: res.statusCode);
    }
  }

  /// Heroku behind a proxy may hand back `http://` next links; Android blocks
  /// cleartext traffic, so always follow them over HTTPS.
  static Uri _secureUri(String url) {
    final uri = Uri.parse(url);
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  /// Paginated typing history from member area.
  Future<ArHistoryPage> fetchTypingHistory({
    int page = 1,
    int pageSize = 100,
  }) async {
    if (!isLoggedIn) throw ArApiException('Not logged in', statusCode: 401);
    final uri = Uri.parse('$baseUrl/learning/typedPassages/').replace(
      queryParameters: {
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    final res = await _authedGet(uri);
    _checkHistoryStatus(res);
    return _parseHistoryPage(res);
  }

  /// Walk `next` until exhausted or [maxPages] (page_size up to 100).
  Future<List<Map<String, dynamic>>> fetchAllHistory({
    int maxPages = 15,
    int pageSize = 100,
  }) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    String? nextUrl;
    while (page <= maxPages) {
      final ArHistoryPage batch;
      if (nextUrl != null) {
        final res = await _authedGet(_secureUri(nextUrl));
        _checkHistoryStatus(res);
        batch = _parseHistoryPage(res);
      } else {
        batch = await fetchTypingHistory(page: page, pageSize: pageSize);
      }
      all.addAll(batch.results);
      if (batch.next == null || batch.results.isEmpty) break;
      nextUrl = batch.next;
      page++;
    }
    return all;
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    if (!isLoggedIn) return null;
    final res = await _authedGet(
      Uri.parse('$baseUrl/learning/students/profile/'),
    );
    if (res.statusCode == 403) {
      throw ArApiException(
        'Your profile is not available on your current AR Typing plan.',
        statusCode: 403,
        freeMode: true,
      );
    }
    if (res.statusCode != 200) {
      throw ArApiException(_errorDetail(res), statusCode: res.statusCode);
    }
    final body = _tryDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    if (body is List && body.isNotEmpty && body.first is Map<String, dynamic>) {
      return body.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchMemberStats() async {
    if (!isLoggedIn) return null;
    final res = await _authedGet(
      Uri.parse('$baseUrl/learning/memberTypingStats/'),
    );
    if (res.statusCode == 403) {
      throw ArApiException(
        'Member stats are not available on your current AR Typing plan.',
        statusCode: 403,
        freeMode: true,
      );
    }
    if (res.statusCode != 200) {
      throw ArApiException(_errorDetail(res), statusCode: res.statusCode);
    }
    final body = _tryDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    return null;
  }

  /// Account + subscription (`/users/me/`): name, email, `is_subscribed`,
  /// `enrollment_date`, `expiration_date`, `days_remaining`, `is_expired`,
  /// `subscription_plan` — what the member-area My Subscription page shows.
  Future<Map<String, dynamic>?> fetchMe() async {
    if (!isLoggedIn) return null;
    final res = await _authedGet(Uri.parse('$baseUrl/users/me/'));
    if (res.statusCode != 200) {
      throw ArApiException(_errorDetail(res), statusCode: res.statusCode);
    }
    final body = _tryDecode(res.body);
    return body is Map<String, dynamic> ? body : null;
  }

  static String _errorDetail(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['detail'] != null) return '${body['detail']}';
        if (body['email'] is List) return (body['email'] as List).join(', ');
        if (body['password'] is List) {
          return (body['password'] as List).join(', ');
        }
        return body.toString();
      }
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  /// Django DecimalFields arrive as strings ("39.60"); accept both.
  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static int? _asInt(dynamic v) => _asDouble(v)?.round();
}

enum _RefreshOutcome { ok, rejected, failed }

class ArHistoryPage {
  final List<Map<String, dynamic>> results;
  final int count;
  final String? next;
  const ArHistoryPage({
    required this.results,
    required this.count,
    required this.next,
  });
}

class ArApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool freeMode;
  final bool needsReauth;
  ArApiException(
    this.message, {
    this.statusCode,
    this.freeMode = false,
    this.needsReauth = false,
  });
  @override
  String toString() => message;
}
