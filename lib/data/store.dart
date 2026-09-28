import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ar_account.dart';
import '../models/ar_result.dart';
import '../models/typing_insight.dart';
import '../services/background_bootstrap.dart';
import '../services/background_sync.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'ar_api.dart';

/// App state. Everything shown comes from the AR Typing member area; nothing
/// is generated locally.
class AppStore extends ChangeNotifier {
  static const _kAccounts = BackgroundSync.kAccounts;
  static const _kActiveAccountId = BackgroundSync.kActiveAccountId;
  static const _kDarkMode = 'tp_dark_mode';

  final ArTypingApi arApi;
  AppStore({ArTypingApi? api}) : arApi = api ?? ArTypingApi();

  bool loaded = false;
  bool darkMode = false;
  bool backgroundSyncEnabled = false;

  List<ArAccount> accounts = [];
  String? activeAccountId;

  /// Typing History, newest first.
  List<ArResult> results = [];
  Map<String, dynamic>? memberStats; // /learning/memberTypingStats/
  Map<String, dynamic>? userInfo; // /users/me/
  Map<String, dynamic>? studentProfile; // /learning/students/profile/
  DateTime? lastSyncedAt;

  bool syncing = false;
  String? statusMessage;
  String? error;

  final Map<int, TypingInsight?> _insightCache = {};
  Timer? _syncTimer;
  bool _foreground = true;
  bool _autoSyncRunning = false;
  Future<int>? _syncInFlight;
  String? _syncInFlightAccount;

  ArAccount? get activeAccount {
    for (final a in accounts) {
      if (a.id == activeAccountId) return a;
    }
    return null;
  }

  /// True when the app should show the welcome / sign-in screen.
  bool get needsLogin => activeAccount == null || !arApi.isLoggedIn;

  // ─── Persistence ────────────────────────────────────────────────────────

  static String historyKey(String id) => BackgroundSync.historyKey(id);
  static String statsKey(String id) => BackgroundSync.statsKey(id);
  static String userInfoKey(String id) => BackgroundSync.userInfoKey(id);
  static String profileKey(String id) => BackgroundSync.remoteProfileKey(id);
  static String syncedAtKey(String id) => BackgroundSync.syncedAtKey(id);

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(_kDarkMode) ?? false;
    AppColors.dark = darkMode;
    backgroundSyncEnabled =
        prefs.getBool(BackgroundSync.kBackgroundSync) ?? false;

    try {
      await _purgeNonWebsiteData(prefs);
      accounts = _decodeAccounts(prefs.getString(_kAccounts));
      activeAccountId = prefs.getString(_kActiveAccountId);
      await _migrateLegacyTokens(prefs);
      if (activeAccount == null && accounts.isNotEmpty) {
        activeAccountId = accounts.first.id;
        await prefs.setString(_kActiveAccountId, activeAccountId!);
      }
      if (activeAccount != null) await _loadActiveAccount(prefs);
    } catch (_) {
      // A corrupt pref or unreadable keystore must not block the app; the
      // user simply signs in again.
      results = [];
    }

    loaded = true;
    notifyListeners();

    try {
      await NotificationService.instance.init();
      await NotificationService.instance.requestPermission();
    } catch (_) {}

    _startAutoSync();
    unawaited(BackgroundSync.setAppForeground(true));
    if (arApi.isLoggedIn) {
      unawaited(syncNow(quiet: true));
      unawaited(BackgroundBootstrap.schedulePeriodicSync());
      if (backgroundSyncEnabled) {
        unawaited(BackgroundBootstrap.startContinuousSync());
      }
    }
  }

  /// Earlier versions stored sample history, a made-up guest profile and
  /// locally computed sessions. None of that is website data — delete it.
  Future<void> _purgeNonWebsiteData(SharedPreferences prefs) async {
    for (final k in prefs.getKeys().toList()) {
      if (k == 'tp_profile' ||
          k == 'tp_sessions' ||
          k.startsWith('tp_profile_') ||
          k.startsWith('tp_sessions_')) {
        await prefs.remove(k);
      }
    }
  }

  static List<ArAccount> _decodeAccounts(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => ArAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _migrateLegacyTokens(SharedPreferences prefs) async {
    if (accounts.isNotEmpty) return;
    final legacy = await arApi.readLegacyTokens();
    final email = legacy['email'];
    final access = legacy['access'];
    if (email == null || email.isEmpty || access == null || access.isEmpty) {
      return;
    }
    final id = ArAccount.idFromEmail(email);
    await arApi.migrateLegacyTokens(id, email);
    accounts = [
      ArAccount(id: id, email: email, displayName: email.split('@').first)
    ];
    activeAccountId = id;
    await _persistAccounts(prefs);
  }

  Future<void> _loadActiveAccount(SharedPreferences prefs) async {
    final acct = activeAccount!;
    await arApi.loadAccount(acct.id, emailHint: acct.email);
    results = _decodeHistory(prefs.getString(historyKey(acct.id)));
    memberStats = _decodeMap(prefs.getString(statsKey(acct.id)));
    userInfo = _decodeMap(prefs.getString(userInfoKey(acct.id)));
    studentProfile = _decodeMap(prefs.getString(profileKey(acct.id)));
    final ts = prefs.getInt(syncedAtKey(acct.id));
    lastSyncedAt = ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
    _insightCache.clear();
  }

  /// Raw typedPassages rows (API order, newest first) → parsed results.
  static List<ArResult> parseRows(List<dynamic> rows) {
    final out = <ArResult>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map<String, dynamic>) continue;
      try {
        out.add(ArResult.fromRow(row, order: rows.length - i));
      } catch (_) {
        // Skip a malformed row rather than failing the whole history.
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static List<ArResult> _decodeHistory(String? raw) {
    if (raw == null) return [];
    try {
      return parseRows(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistAccounts(SharedPreferences prefs) async {
    await prefs.setString(
        _kAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
    if (activeAccountId != null) {
      await prefs.setString(_kActiveAccountId, activeAccountId!);
    } else {
      await prefs.remove(_kActiveAccountId);
    }
  }

  void _clearAccountData() {
    results = [];
    memberStats = null;
    userInfo = null;
    studentProfile = null;
    lastSyncedAt = null;
    _insightCache.clear();
  }

  // ─── Sign in / accounts ─────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    error = null;
    statusMessage = 'Signing in…';
    syncing = true;
    notifyListeners();
    try {
      final id = ArAccount.idFromEmail(email);
      await arApi.login(email: email, password: password, accountId: id);
      if (!accounts.any((a) => a.id == id)) {
        accounts = [
          ...accounts,
          ArAccount(
            id: id,
            email: email.trim(),
            displayName: email.trim().split('@').first,
          ),
        ];
      }
      activeAccountId = id;
      final prefs = await SharedPreferences.getInstance();
      await _persistAccounts(prefs);
      _clearAccountData();
      // Cached history for an account signed in before shows immediately.
      await _loadActiveAccount(prefs);

      statusMessage = 'Signed in — fetching your typing history…';
      syncing = false;
      notifyListeners();
      await syncNow();
      unawaited(BackgroundBootstrap.schedulePeriodicSync());
      if (backgroundSyncEnabled) {
        unawaited(BackgroundBootstrap.startContinuousSync());
      }
      return true;
    } on ArApiException catch (e) {
      error = e.message;
      statusMessage = null;
      return false;
    } on TimeoutException {
      error = 'AR Typing is taking too long to respond. Try again.';
      statusMessage = null;
      return false;
    } catch (_) {
      error = 'Could not reach AR Typing. Check your connection.';
      statusMessage = null;
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> switchAccount(String id) async {
    if (id == activeAccountId || !accounts.any((a) => a.id == id)) return;
    activeAccountId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveAccountId, id);
    _clearAccountData();
    await _loadActiveAccount(prefs);
    error = null;
    statusMessage = 'Switched to ${activeAccount?.displayName ?? id}';
    notifyListeners();
    if (arApi.isLoggedIn) unawaited(syncNow(quiet: true));
  }

  Future<void> removeAccount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await arApi.deleteTokensFor(id);
    for (final k in [
      historyKey(id),
      statsKey(id),
      userInfoKey(id),
      profileKey(id),
      syncedAtKey(id),
    ]) {
      await prefs.remove(k);
    }
    accounts = accounts.where((a) => a.id != id).toList();
    if (activeAccountId == id) {
      _clearAccountData();
      activeAccountId = accounts.isEmpty ? null : accounts.first.id;
      if (activeAccountId != null) {
        await _loadActiveAccount(prefs);
      } else {
        unawaited(BackgroundBootstrap.stopContinuousSync());
        unawaited(BackgroundBootstrap.cancelPeriodicSync());
      }
    }
    await _persistAccounts(prefs);
    error = null;
    statusMessage = 'Account removed';
    notifyListeners();
  }

  /// Signs out of the active account. It stays in the account list, and the
  /// welcome screen asks for its password again.
  Future<void> logout() async {
    syncing = true;
    notifyListeners();
    try {
      await arApi.logoutRemote();
    } finally {
      syncing = false;
      statusMessage = null;
      error = null;
      notifyListeners();
    }
  }

  // ─── Sync ───────────────────────────────────────────────────────────────

  /// Fetch profile, subscription, member stats and the full Typing History.
  /// Concurrent callers share one in-flight request per account.
  Future<int> syncNow({bool notifyOnNew = false, bool quiet = false}) {
    final running = _syncInFlight;
    if (running != null && _syncInFlightAccount == activeAccountId) {
      return running;
    }
    final f = _sync(notifyOnNew: notifyOnNew, quiet: quiet);
    _syncInFlight = f;
    _syncInFlightAccount = activeAccountId;
    return f.whenComplete(() {
      if (identical(_syncInFlight, f)) {
        _syncInFlight = null;
        _syncInFlightAccount = null;
      }
    });
  }

  Future<int> _sync({required bool notifyOnNew, required bool quiet}) async {
    if (!arApi.isLoggedIn) return 0;
    if (!quiet) {
      syncing = true;
      error = null;
      statusMessage = 'Fetching typing history…';
      notifyListeners();
    }
    final accountId = activeAccountId;
    bool stale() => activeAccountId != accountId;
    final previousIds = results.map((r) => r.id).toSet();
    String? planNote;

    Future<Map<String, dynamic>?> optional(
        Future<Map<String, dynamic>?> Function() call) async {
      try {
        return await call();
      } on ArApiException catch (e) {
        if (e.needsReauth) rethrow;
        if (e.freeMode) planNote = e.message;
        return null;
      }
    }

    try {
      final me = await optional(arApi.fetchMe);
      final profile = await optional(arApi.fetchProfile);
      final stats = await optional(arApi.fetchMemberStats);
      final rows = await arApi.fetchAllHistory(maxPages: 15, pageSize: 100);
      if (stale()) return 0;

      final parsed = parseRows(rows);
      results = parsed;
      if (me != null) userInfo = me;
      if (profile != null) studentProfile = profile;
      if (stats != null) memberStats = stats;
      lastSyncedAt = DateTime.now();
      _insightCache.clear();

      final name = displayName;
      if (name != null) {
        accounts = accounts
            .map((a) => a.id == accountId ? a.copyWith(displayName: name) : a)
            .toList();
      }

      final prefs = await SharedPreferences.getInstance();
      final id = accountId!;
      await prefs.setString(historyKey(id), jsonEncode(rows));
      if (stats != null) await prefs.setString(statsKey(id), jsonEncode(stats));
      if (me != null) await prefs.setString(userInfoKey(id), jsonEncode(me));
      if (profile != null) {
        await prefs.setString(profileKey(id), jsonEncode(profile));
      }
      await prefs.setInt(syncedAtKey(id), lastSyncedAt!.millisecondsSinceEpoch);
      await _persistAccounts(prefs);

      if (notifyOnNew) await _notifyNew(previousIds);
      if (!quiet) {
        statusMessage = planNote ??
            'Synced ${parsed.length} result${parsed.length == 1 ? '' : 's'}';
      }
      return parsed.length;
    } on ArApiException catch (e) {
      if (stale()) return 0;
      // needsReauth: tokens are cleared, so needsLogin shows the sign-in page.
      if (e.needsReauth || !quiet) error = e.message;
      statusMessage = null;
      return 0;
    } catch (e) {
      if (!quiet && !stale()) {
        error = e is TimeoutException
            ? 'AR Typing is taking too long to respond. Try again.'
            : 'Sync failed. Check your connection and try again.';
        statusMessage = null;
      }
      return 0;
    } finally {
      if (!quiet) syncing = false;
      notifyListeners();
    }
  }

  Future<void> _notifyNew(Set<String> previousIds) async {
    if (previousIds.isEmpty) return; // first sync: nothing is "new"
    final fresh = results.where((r) => !previousIds.contains(r.id)).toList();
    if (fresh.isEmpty) return;
    try {
      await NotificationService.instance.showNewResult(
        title: fresh.length == 1
            ? 'New typing result'
            : '${fresh.length} new typing results',
        body: BackgroundSync.resultSummary(fresh.first),
      );
    } catch (_) {}
  }

  Future<void> manualRefresh() => syncNow(notifyOnNew: true);

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_autoSyncTick());
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _autoSyncTick() async {
    if (!_foreground || !arApi.isLoggedIn || _autoSyncRunning || syncing) {
      return;
    }
    _autoSyncRunning = true;
    try {
      await syncNow(notifyOnNew: true, quiet: true);
    } finally {
      _autoSyncRunning = false;
    }
  }

  void onAppLifecycle(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    unawaited(BackgroundSync.setAppForeground(_foreground));
    if (state == AppLifecycleState.resumed) {
      unawaited(_reloadFromBackground());
      unawaited(_autoSyncTick());
    } else if (wasForeground &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      if (backgroundSyncEnabled && arApi.isLoggedIn) {
        unawaited(BackgroundBootstrap.startContinuousSync());
      }
    }
  }

  /// Pick up history written by the Workmanager / foreground-service isolate.
  Future<void> _reloadFromBackground() async {
    final id = activeAccountId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    if (activeAccountId != id) return;
    final raw = prefs.getString(historyKey(id));
    if (raw != null) results = _decodeHistory(raw);
    memberStats = _decodeMap(prefs.getString(statsKey(id))) ?? memberStats;
    final ts = prefs.getInt(syncedAtKey(id));
    if (ts != null) lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    notifyListeners();
  }

  Future<void> setBackgroundSyncEnabled(bool enabled) async {
    backgroundSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BackgroundSync.kBackgroundSync, enabled);
    notifyListeners();
    if (enabled && arApi.isLoggedIn) {
      await BackgroundBootstrap.schedulePeriodicSync();
    }
    await BackgroundBootstrap.setKeepSyncingInBackground(enabled);
  }

  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    AppColors.dark = darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, darkMode);
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    // A sync can finish after the store is gone (e.g. app closing).
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopAutoSync();
    super.dispose();
  }

  // ─── Typing Insight ─────────────────────────────────────────────────────

  /// `/learning/typing-progress/?days=` — cached until the next sync.
  /// Returns null when the website has no activity in that window.
  Future<TypingInsight?> loadInsight(int days, {bool force = false}) async {
    if (!force && _insightCache.containsKey(days)) return _insightCache[days];
    final accountAtStart = activeAccountId;
    final raw = await arApi.fetchTypingProgress(days);
    final insight = raw == null ? null : TypingInsight.fromJson(days, raw);
    if (activeAccountId == accountAtStart) _insightCache[days] = insight;
    return insight;
  }

  // ─── Member stats (the four cards on the website) ───────────────────────

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  int? get totalTests => _num(memberStats?['total_tests'])?.round();
  double? get avgGross => _num(memberStats?['avg_gross_speed']);
  double? get avgNet => _num(memberStats?['avg_net_speed']);
  double? get avgAccuracy => _num(memberStats?['avg_accuracy_percentage']);

  /// The last [n] results that have speeds, oldest → newest. Results without
  /// data (NA) are left out rather than drawn as 0.
  List<ArResult> lastResultsForChart(int n) => results
      .where((r) => _has(r.grossWpm) || _has(r.netWpm))
      .take(n)
      .toList()
      .reversed
      .toList();

  static bool _has(double? v) => v != null && v > 0;

  // ─── Profile / subscription (/users/me/, /learning/students/profile/) ──

  String? get displayName {
    String? pick(Map<String, dynamic>? m) {
      if (m == null) return null;
      final first = m['first_name'];
      final last = m['last_name'];
      if (first is String && first.trim().isNotEmpty) {
        return '${first.trim()} ${last is String ? last.trim() : ''}'.trim();
      }
      for (final k in ['full_name', 'name', 'student_name']) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      for (final k in ['student', 'user']) {
        final nested = m[k];
        if (nested is Map<String, dynamic>) {
          final n = pick(nested);
          if (n != null) return n;
        }
      }
      return null;
    }

    return pick(userInfo) ?? pick(studentProfile);
  }

  String? get email {
    final e = userInfo?['email'];
    return e is String && e.isNotEmpty ? e : activeAccount?.email;
  }

  bool? get isSubscribed {
    final v = userInfo?['is_subscribed'];
    return v is bool ? v : null;
  }

  bool get isExpired => userInfo?['is_expired'] == true;

  String? get planName {
    final plan = userInfo?['subscription_plan'] ?? userInfo?['subscription'];
    if (plan is Map) {
      final n = plan['name'] ?? plan['title'];
      if (n is String && n.trim().isNotEmpty) return n.trim();
    }
    final s = isSubscribed;
    if (s == null) return null;
    return s ? 'Premium Plan' : 'Free Plan'; // the website's own labels
  }

  DateTime? get enrollmentDate => _date(userInfo?['enrollment_date']);
  DateTime? get expirationDate => _date(userInfo?['expiration_date']);
  int? get daysRemaining => _num(userInfo?['days_remaining'])?.round();

  static DateTime? _date(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toLocal();
  }
}
