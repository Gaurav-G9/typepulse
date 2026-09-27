import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/session.dart';

/// Client for AR Typing Platform backend (Heroku API used by artypingplatform.com).
///
/// Endpoints discovered from the public Next.js bundles:
/// - POST /jwt/create/          {email, password} → {access, refresh}
/// - POST /jwt/refresh/         {refresh} → {access}
/// - POST /logout/              {refresh} + JWT
/// - GET  /learning/typedPassages/?page=&page_size=
/// - GET  /learning/memberTypingStats/
/// - GET  /learning/students/profile/
class ArTypingApi {
  static const baseUrl =
      'https://artypingplatform-efb5438ddb1b.herokuapp.com/api/v1';
  static const siteUrl = 'https://www.artypingplatform.com';

  static const _kAccess = 'ar_access_token';
  static const _kRefresh = 'ar_refresh_token';
  static const _kEmail = 'ar_email';

  final FlutterSecureStorage _secure;
  final http.Client _http;

  String? accessToken;
  String? refreshToken;
  String? email;

  ArTypingApi({
    FlutterSecureStorage? secure,
    http.Client? httpClient,
  })  : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _http = httpClient ?? http.Client();

  bool get isLoggedIn =>
      accessToken != null && accessToken!.isNotEmpty;

  Future<void> loadStoredSession() async {
    accessToken = await _secure.read(key: _kAccess);
    refreshToken = await _secure.read(key: _kRefresh);
    email = await _secure.read(key: _kEmail);
  }

  Future<void> _persist() async {
    if (accessToken != null) {
      await _secure.write(key: _kAccess, value: accessToken!);
    } else {
      await _secure.delete(key: _kAccess);
    }
    if (refreshToken != null) {
      await _secure.write(key: _kRefresh, value: refreshToken!);
    } else {
      await _secure.delete(key: _kRefresh);
    }
    if (email != null) {
      await _secure.write(key: _kEmail, value: email!);
    } else {
      await _secure.delete(key: _kEmail);
    }
  }

  Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    email = null;
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    await _secure.delete(key: _kEmail);
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'JWT $accessToken',
      };

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/jwt/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<bool> refreshAccessToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    final res = await _http.post(
      Uri.parse('$baseUrl/jwt/refresh/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      accessToken = body['access'] as String?;
      await _persist();
      return accessToken != null;
    }
    return false;
  }

  Future<void> logoutRemote() async {
    try {
      if (accessToken != null && refreshToken != null) {
        await _http.post(
          Uri.parse('$baseUrl/logout/'),
          headers: _authHeaders,
          body: jsonEncode({'refresh': refreshToken}),
        );
      }
    } catch (_) {
      // Best-effort remote logout.
    }
    await clearSession();
  }

  Future<http.Response> _authedGet(Uri uri) async {
    var res = await _http.get(uri, headers: _authHeaders);
    if (res.statusCode == 401) {
      final ok = await refreshAccessToken();
      if (ok) {
        res = await _http.get(uri, headers: _authHeaders);
      }
    }
    return res;
  }

  /// Paginated typing history from member area.
  Future<ArHistoryPage> fetchTypingHistory({
    int page = 1,
    int pageSize = 50,
  }) async {
    if (!isLoggedIn) throw ArApiException('Not logged in', statusCode: 401);
    final uri = Uri.parse('$baseUrl/learning/typedPassages/').replace(
      queryParameters: {
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    final res = await _authedGet(uri);
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
    final body = jsonDecode(res.body);
    if (body is List) {
      return ArHistoryPage(
        results: body.cast<Map<String, dynamic>>(),
        count: body.length,
        next: null,
      );
    }
    final map = body as Map<String, dynamic>;
    final results = (map['results'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    return ArHistoryPage(
      results: results,
      count: map['count'] as int? ?? results.length,
      next: map['next'] as String?,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllHistory({
    int maxPages = 10,
    int pageSize = 50,
  }) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    while (page <= maxPages) {
      final batch = await fetchTypingHistory(page: page, pageSize: pageSize);
      all.addAll(batch.results);
      if (batch.next == null || batch.results.isEmpty) break;
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
        'Profile insights gated on Free Mode.',
        statusCode: 403,
        freeMode: true,
      );
    }
    if (res.statusCode != 200) {
      throw ArApiException(_errorDetail(res), statusCode: res.statusCode);
    }
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    if (body is List && body.isNotEmpty) {
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
        'Typing insights are locked on Free Mode. Local Summary still works.',
        statusCode: 403,
        freeMode: true,
      );
    }
    if (res.statusCode != 200) {
      throw ArApiException(_errorDetail(res), statusCode: res.statusCode);
    }
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    return null;
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

  /// Map one AR typedPassages row → TypingSession for Fitness-style UI.
  static TypingSession sessionFromRemote(Map<String, dynamic> e) {
    final idRaw = e['id'];
    final id = 'ar-$idRaw';
    final exam = (e['exam_title'] ?? e['exam_name'] ?? 'AR Typing Exam')
        .toString();
    final passage = (e['passage_title'] ?? 'Passage').toString();
    final created = _parseDate(e['created_at']) ?? DateTime.now();

    final durationSec = _parseDurationSec(e['time_duration']);
    // Site stores time_taken in minutes (see web: 60 * time_taken * 1000).
    final timeTakenRaw = (e['time_taken'] as num?)?.toDouble() ?? 0;
    var timeTakenSec = (timeTakenRaw * 60).round();
    if (timeTakenSec <= 0) timeTakenSec = durationSec > 0 ? durationSec : 1;

    final keyGiven = (e['key_strokes_given'] as num?)?.toInt() ?? 0;
    final keyTyped = (e['key_strokes_typed'] as num?)?.toInt() ?? 0;
    final target = (e['target_speed'] as num?)?.toInt() ?? 30;
    var gross = (e['gross_speed'] as num?)?.toDouble() ?? 0;
    var net = (e['net_speed'] as num?)?.toDouble() ?? 0;
    if (gross == 0 && keyTyped > 0 && timeTakenRaw > 0) {
      gross = keyTyped / (timeTakenRaw * 5);
    }

    final wordsTyped = keyTyped / 5.0;
    final backspaces = (e['back_space_count'] as num?)?.toInt() ?? 0;
    final qualified = e['qualified'] as bool? ?? (net >= target);
    final full = (e['full_mistake'] as num?)?.toInt() ??
        (e['full_mistakes'] as num?)?.toInt() ??
        0;
    final half = (e['half_mistake'] as num?)?.toInt() ??
        (e['half_mistakes'] as num?)?.toInt() ??
        0;
    final totalWrong = (e['total_wrong_words'] as num?)?.toDouble() ??
        (full + half * 0.5);
    final lang = _guessLang(exam, e['language_id']);

    final expected = e['passage_text'] as String?;
    final typed = e['typed_passage_text'] as String?;

    // Approximate accuracy from correct chars if not provided.
    final accuracy = (e['accuracy'] as num?)?.toDouble() ??
        (keyTyped == 0
            ? 0.0
            : ((1 - (totalWrong / (wordsTyped == 0 ? 1 : wordsTyped))) * 100)
                .clamp(0, 100));

    return TypingSession(
      id: id,
      startedAt: created,
      durationSec: durationSec > 0 ? durationSec : 300,
      timeTakenSec: timeTakenSec,
      language: lang,
      mode: 'ar_sync',
      examTitle: exam,
      passageTitle: passage,
      keystrokesGiven: keyGiven,
      typedChars: keyTyped,
      correctChars: (keyTyped * (accuracy / 100)).round().clamp(0, keyTyped),
      errors: (keyTyped - (keyTyped * (accuracy / 100)).round()).clamp(0, keyTyped),
      wordsTyped: wordsTyped,
      fullMistakes: full,
      halfMistakes: half,
      totalWrongWords: totalWrong,
      netWrongWords: (e['net_wrong_words'] as num?)?.toDouble() ?? 0,
      backspaceCount: backspaces,
      wpm: gross,
      netWpm: net,
      accuracy: accuracy.toDouble(),
      qualified: qualified,
      formulaNote:
          'Synced from AR Typing · Net ${net.toStringAsFixed(2)} / Gross ${gross.toStringAsFixed(2)} · target $target',
      targetWpm: target,
      expectedText: expected,
      typedText: typed,
      source: 'ar',
    );
  }

  static String _guessLang(String exam, dynamic languageId) {
    final lower = exam.toLowerCase();
    if (lower.contains('hindi') || lower.contains('mangal') || lower.contains('krutidev')) {
      return 'hi';
    }
    if (languageId == 2 || languageId == '2') return 'hi';
    return 'en';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static int _parseDurationSec(dynamic v) {
    if (v == null) return 300;
    if (v is num) return (v * 60).round(); // minutes
    final s = v.toString();
    final parts = s.split(':');
    try {
      if (parts.length == 3) {
        return int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            int.parse(parts[2]);
      }
      if (parts.length == 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (_) {}
    return 300;
  }
}

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
  ArApiException(this.message, {this.statusCode, this.freeMode = false});
  @override
  String toString() => message;
}
