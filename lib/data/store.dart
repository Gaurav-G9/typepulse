import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ar_account.dart';
import '../models/leaderboard_entry.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'ar_api.dart';
import 'scoring.dart';

class AppStore extends ChangeNotifier {
  static const _kAccounts = 'tp_accounts';
  static const _kActiveAccountId = 'tp_active_account_id';
  static const _kDarkMode = 'tp_dark_mode';
  // Legacy single-account keys.
  static const _kLegacyProfile = 'tp_profile';
  static const _kLegacySessions = 'tp_sessions';

  List<ArAccount> accounts = [];
  String? activeAccountId;

  UserProfile profile = UserProfile.guest;
  List<TypingSession> sessions = [];
  bool loaded = false;
  bool darkMode = false;

  final ArTypingApi arApi = ArTypingApi();
  bool arConnected = false;
  bool arSyncing = false;
  bool refreshing = false;
  String? arStatusMessage;
  String? arError;
  Map<String, dynamic>? arRemoteProfile;
  Map<String, dynamic>? arMemberStats;

  Timer? _syncTimer;
  bool _foreground = true;
  bool _autoSyncRunning = false;

  ArAccount? get activeAccount {
    if (activeAccountId == null) return null;
    try {
      return accounts.firstWhere((a) => a.id == activeAccountId);
    } catch (_) {
      return null;
    }
  }

  String _profileKey(String id) => 'tp_profile_$id';
  String _sessionsKey(String id) => 'tp_sessions_$id';
  String _statsKey(String id) => 'tp_member_stats_$id';
  String _remoteProfileKey(String id) => 'tp_remote_profile_$id';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    darkMode = prefs.getBool(_kDarkMode) ?? false;
    AppColors.dark = darkMode;

    await _loadAccounts(prefs);
    await _migrateLegacyIfNeeded(prefs);

    if (activeAccountId != null &&
        accounts.any((a) => a.id == activeAccountId)) {
      await _loadActiveAccountData(prefs);
    } else if (accounts.isNotEmpty) {
      activeAccountId = accounts.first.id;
      await prefs.setString(_kActiveAccountId, activeAccountId!);
      await _loadActiveAccountData(prefs);
    } else {
      // Local-only guest until an AR account is added.
      final p = prefs.getString(_kLegacyProfile);
      if (p != null) {
        profile = UserProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
        darkMode = profile.darkMode;
        AppColors.dark = darkMode;
        await prefs.setBool(_kDarkMode, darkMode);
      } else {
        profile = UserProfile.guest.copyWith(targetWpm: 30, dailyGoalMinutes: 25);
      }
      final s = prefs.getString(_kLegacySessions);
      if (s != null) {
        final list = jsonDecode(s) as List<dynamic>;
        sessions = list
            .map((e) => TypingSession.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      }
      _ensureSeedHistory();
      await _persistLocalGuest(prefs);
    }

    arConnected = arApi.isLoggedIn;
    loaded = true;
    notifyListeners();

    try {
      await NotificationService.instance.init();
    } catch (_) {}

    startAutoSync();
    if (arApi.isLoggedIn) {
      // Initial quiet pull so Summary is fresh after cold start.
      unawaited(syncArHistory(notifyOnNew: false, quiet: true));
    }
  }

  Future<void> _loadAccounts(SharedPreferences prefs) async {
    final raw = prefs.getString(_kAccounts);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      accounts = list
          .map((e) => ArAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    activeAccountId = prefs.getString(_kActiveAccountId);
  }

  Future<void> _migrateLegacyIfNeeded(SharedPreferences prefs) async {
    if (accounts.isNotEmpty) return;
    final legacy = await arApi.readLegacyTokens();
    final email = legacy['email'];
    final access = legacy['access'];
    if (email == null || email.isEmpty || access == null || access.isEmpty) {
      return;
    }
    final id = ArAccount.idFromEmail(email);
    await arApi.migrateLegacyTokens(id, email);
    final name = prefs.getString(_kLegacyProfile) != null
        ? (UserProfile.fromJson(
                jsonDecode(prefs.getString(_kLegacyProfile)!)
                    as Map<String, dynamic>)
            .name)
        : email.split('@').first;
    accounts = [ArAccount(id: id, email: email, displayName: name)];
    activeAccountId = id;
    await prefs.setString(_kAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
    await prefs.setString(_kActiveAccountId, id);

    // Move legacy profile/sessions into per-account keys.
    final lp = prefs.getString(_kLegacyProfile);
    if (lp != null) {
      await prefs.setString(_profileKey(id), lp);
      final up = UserProfile.fromJson(jsonDecode(lp) as Map<String, dynamic>);
      darkMode = up.darkMode;
      await prefs.setBool(_kDarkMode, darkMode);
    }
    final ls = prefs.getString(_kLegacySessions);
    if (ls != null) await prefs.setString(_sessionsKey(id), ls);
  }

  Future<void> _loadActiveAccountData(SharedPreferences prefs) async {
    final id = activeAccountId!;
    final acct = activeAccount!;
    await arApi.loadAccount(id, emailHint: acct.email);
    arConnected = arApi.isLoggedIn;

    final p = prefs.getString(_profileKey(id));
    if (p != null) {
      profile = UserProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
    } else {
      profile = UserProfile(
        id: id,
        name: acct.displayName,
        handle: '@${acct.email.split('@').first}',
        targetWpm: 30,
        dailyGoalMinutes: 25,
        darkMode: darkMode,
      );
    }
    // Theme is device-global, not per-account.
    profile = profile.copyWith(darkMode: darkMode);

    final s = prefs.getString(_sessionsKey(id));
    if (s != null) {
      final list = jsonDecode(s) as List<dynamic>;
      sessions = list
          .map((e) => TypingSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } else {
      sessions = [];
    }

    final st = prefs.getString(_statsKey(id));
    arMemberStats = st != null ? jsonDecode(st) as Map<String, dynamic> : null;
    final rp = prefs.getString(_remoteProfileKey(id));
    arRemoteProfile =
        rp != null ? jsonDecode(rp) as Map<String, dynamic> : null;

    _ensureSeedHistory();
  }

  void _ensureSeedHistory() {
    final needsSeed = !profile.seededFromArHistory &&
        (sessions.isEmpty ||
            (sessions.length <= 1 &&
                sessions.every((e) =>
                    e.id == 'sample-upsssc' || e.source == 'local')));
    if (needsSeed || sessions.isEmpty) {
      sessions = seedHistory();
      profile = profile.copyWith(seededFromArHistory: true);
    }
  }

  Future<void> _persistAccounts(SharedPreferences prefs) async {
    await prefs.setString(
      _kAccounts,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
    if (activeAccountId != null) {
      await prefs.setString(_kActiveAccountId, activeAccountId!);
    } else {
      await prefs.remove(_kActiveAccountId);
    }
  }

  Future<void> _persistActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, darkMode);
    final id = activeAccountId;
    if (id == null) {
      await _persistLocalGuest(prefs);
      return;
    }
    await prefs.setString(_profileKey(id), jsonEncode(profile.toJson()));
    await prefs.setString(
      _sessionsKey(id),
      jsonEncode(sessions.map((e) => e.toJson()).toList()),
    );
    if (arMemberStats != null) {
      await prefs.setString(_statsKey(id), jsonEncode(arMemberStats));
    }
    if (arRemoteProfile != null) {
      await prefs.setString(
          _remoteProfileKey(id), jsonEncode(arRemoteProfile));
    }
    await _persistAccounts(prefs);
  }

  Future<void> _persistLocalGuest(SharedPreferences prefs) async {
    await prefs.setString(_kLegacyProfile, jsonEncode(profile.toJson()));
    await prefs.setString(
      _kLegacySessions,
      jsonEncode(sessions.map((e) => e.toJson()).toList()),
    );
    await prefs.setBool(_kDarkMode, darkMode);
  }

  Future<void> updateProfile(UserProfile next) async {
    profile = next.copyWith(darkMode: darkMode);
    await _persistActive();
    notifyListeners();
  }

  Future<void> addSession(TypingSession session) async {
    sessions = [session, ...sessions];
    await _persistActive();
    notifyListeners();
  }

  // ─── Multi-account ──────────────────────────────────────────────────────

  Future<bool> arLogin(String email, String password) async {
    arError = null;
    arStatusMessage = 'Signing in…';
    arSyncing = true;
    notifyListeners();
    try {
      final id = ArAccount.idFromEmail(email);
      // Persist current account before switching.
      if (activeAccountId != null && activeAccountId != id) {
        await _persistActive();
      }

      await arApi.login(email: email, password: password, accountId: id);
      arConnected = true;

      final existing = accounts.where((a) => a.id == id).toList();
      if (existing.isEmpty) {
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

      // Load any previously cached data for this account, else fresh profile.
      final cached = prefs.getString(_profileKey(id));
      if (cached != null) {
        profile = UserProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>)
            .copyWith(darkMode: darkMode);
        final s = prefs.getString(_sessionsKey(id));
        if (s != null) {
          sessions = (jsonDecode(s) as List<dynamic>)
              .map((e) => TypingSession.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        } else {
          sessions = [];
        }
      } else {
        final localName = email.trim().split('@').first;
        profile = UserProfile(
          id: id,
          name: localName,
          handle: '@$localName',
          targetWpm: 30,
          dailyGoalMinutes: 25,
          darkMode: darkMode,
        );
        sessions = [];
      }

      arStatusMessage = 'Signed in — syncing history…';
      notifyListeners();
      await syncArHistory(notifyOnNew: false);
      return true;
    } on ArApiException catch (e) {
      arError = e.message;
      arStatusMessage = null;
      arConnected = arApi.isLoggedIn;
      return false;
    } catch (e) {
      arError = 'Could not reach AR Typing. Check your connection.';
      arStatusMessage = null;
      return false;
    } finally {
      arSyncing = false;
      notifyListeners();
    }
  }

  Future<void> switchAccount(String id) async {
    if (id == activeAccountId) return;
    if (!accounts.any((a) => a.id == id)) return;

    await _persistActive();
    activeAccountId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveAccountId, id);
    await _loadActiveAccountData(prefs);
    arError = null;
    arStatusMessage = 'Switched to ${activeAccount?.displayName ?? id}';
    notifyListeners();

    // Quiet refresh for the newly active account.
    if (arApi.isLoggedIn) {
      unawaited(syncArHistory(notifyOnNew: false, quiet: true));
    }
  }

  Future<void> removeAccount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await arApi.deleteTokensFor(id);
    await prefs.remove(_profileKey(id));
    await prefs.remove(_sessionsKey(id));
    await prefs.remove(_statsKey(id));
    await prefs.remove(_remoteProfileKey(id));

    accounts = accounts.where((a) => a.id != id).toList();

    if (activeAccountId == id) {
      if (accounts.isNotEmpty) {
        activeAccountId = accounts.first.id;
        await prefs.setString(_kActiveAccountId, activeAccountId!);
        await _loadActiveAccountData(prefs);
      } else {
        activeAccountId = null;
        await prefs.remove(_kActiveAccountId);
        arApi.accountId = null;
        arApi.accessToken = null;
        arApi.refreshToken = null;
        arApi.email = null;
        arConnected = false;
        arRemoteProfile = null;
        arMemberStats = null;
        profile = UserProfile.guest.copyWith(
          targetWpm: 30,
          dailyGoalMinutes: 25,
          darkMode: darkMode,
        );
        sessions = seedHistory();
        profile = profile.copyWith(seededFromArHistory: true);
      }
    }

    await _persistAccounts(prefs);
    await _persistActive();
    arStatusMessage = 'Account removed';
    arError = null;
    notifyListeners();
  }

  Future<void> arLogout() async {
    // Logout only clears tokens for the active account; keep it in the list
    // so the user can re-auth, or remove via account switcher.
    arSyncing = true;
    notifyListeners();
    try {
      await arApi.logoutRemote();
    } finally {
      arConnected = false;
      arRemoteProfile = null;
      arMemberStats = null;
      arStatusMessage = 'Signed out of AR Typing';
      arError = null;
      arSyncing = false;
      notifyListeners();
      await _persistActive();
    }
  }

  // ─── Sync / refresh ─────────────────────────────────────────────────────

  Future<int> syncArHistory({
    bool notifyOnNew = false,
    bool quiet = false,
  }) async {
    if (!arApi.isLoggedIn) {
      if (!quiet) {
        arError = 'Sign in to AR Typing first.';
        notifyListeners();
      }
      return 0;
    }
    if (!quiet) {
      arSyncing = true;
      arError = null;
      arStatusMessage = 'Fetching typing history…';
      notifyListeners();
    }

    final previousIds = sessions.map((s) => s.id).toSet();
    final previousCount = sessions
        .where((s) => s.source == 'ar' || s.id.startsWith('ar-'))
        .length;

    try {
      try {
        arRemoteProfile = await arApi.fetchProfile();
        final name = _pickName(arRemoteProfile);
        if (name != null && name.isNotEmpty) {
          profile = profile.copyWith(name: name);
          // Update display name on account card.
          if (activeAccountId != null) {
            accounts = accounts
                .map((a) => a.id == activeAccountId
                    ? a.copyWith(displayName: name)
                    : a)
                .toList();
          }
        }
      } on ArApiException catch (e) {
        if (e.needsReauth) {
          arConnected = false;
          arError = e.message;
          notifyListeners();
          return 0;
        }
        if (e.freeMode && !quiet) {
          arStatusMessage = e.message;
        }
      }

      try {
        arMemberStats = await arApi.fetchMemberStats();
      } on ArApiException catch (e) {
        if (e.needsReauth) {
          arConnected = false;
          arError = e.message;
          notifyListeners();
          return 0;
        }
        if (e.freeMode && !quiet) {
          arError = e.message;
        }
      }

      final remote = await arApi.fetchAllHistory(maxPages: 15, pageSize: 100);
      final mapped = remote.map(ArTypingApi.sessionFromRemote).toList();

      final localOnly = sessions
          .where((s) => s.source != 'ar' && !s.id.startsWith('ar-'))
          .toList();
      final keptLocal = mapped.isEmpty
          ? localOnly
          : localOnly
              .where((s) => !s.id.startsWith('seed-') && s.id != 'sample-upsssc')
              .toList();

      sessions = [...mapped, ...keptLocal]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

      profile = profile.copyWith(seededFromArHistory: true);
      await _persistActive();

      if (notifyOnNew) {
        await _notifyNewResults(previousIds, previousCount, mapped);
      }

      if (!quiet) {
        arStatusMessage =
            'Synced ${mapped.length} AR workout${mapped.length == 1 ? '' : 's'}';
      }
      return mapped.length;
    } on ArApiException catch (e) {
      if (e.needsReauth) arConnected = false;
      if (!quiet) {
        arError = e.message;
        arStatusMessage = null;
      }
      return 0;
    } catch (e) {
      if (!quiet) {
        arError = 'Sync failed. Try again.';
        arStatusMessage = null;
      }
      return 0;
    } finally {
      if (!quiet) arSyncing = false;
      notifyListeners();
    }
  }

  Future<void> manualRefresh() async {
    if (!arApi.isLoggedIn) {
      arError = 'Sign in to AR Typing first.';
      notifyListeners();
      return;
    }
    refreshing = true;
    notifyListeners();
    try {
      await syncArHistory(notifyOnNew: true, quiet: false);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _notifyNewResults(
    Set<String> previousIds,
    int previousCount,
    List<TypingSession> mapped,
  ) async {
    final newOnes = mapped.where((s) => !previousIds.contains(s.id)).toList();
    if (newOnes.isEmpty && mapped.length <= previousCount) return;
    if (newOnes.isEmpty) return;

    // Newest first already — notify about the latest new result (avoid spam).
    final latest = newOnes.first;
    final examShort = latest.examTitle.length > 28
        ? '${latest.examTitle.substring(0, 28)}…'
        : latest.examTitle;
    final body =
        '$examShort · Net ${latest.netWpm.toStringAsFixed(1)} WPM';
    try {
      await NotificationService.instance.showNewResult(
        title: newOnes.length == 1
            ? 'New typing result'
            : '${newOnes.length} new typing results',
        body: body,
      );
    } catch (_) {}
  }

  // ─── Auto-sync every 30s while foreground ───────────────────────────────

  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_autoSyncTick());
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void onAppLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (state == AppLifecycleState.resumed) {
      unawaited(_autoSyncTick());
    }
  }

  Future<void> _autoSyncTick() async {
    if (!_foreground || !arApi.isLoggedIn || _autoSyncRunning || arSyncing) {
      return;
    }
    _autoSyncRunning = true;
    try {
      await syncArHistory(notifyOnNew: true, quiet: true);
    } finally {
      _autoSyncRunning = false;
    }
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }

  String? _pickName(Map<String, dynamic>? p) {
    if (p == null) return null;
    for (final k in [
      'full_name',
      'name',
      'student_name',
      'first_name',
      'display_name',
    ]) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final first = p['first_name'];
    final last = p['last_name'];
    if (first is String) {
      return '${first.trim()} ${last is String ? last.trim() : ''}'.trim();
    }
    return null;
  }

  // ─── Member stats helpers for Summary cards ─────────────────────────────

  int? get remoteTotalTests {
    final s = arMemberStats;
    if (s == null) return null;
    for (final k in [
      'total_tests',
      'total_passages',
      'total_typed_passages',
      'count',
      'tests_count',
    ]) {
      final v = s[k];
      if (v is num) return v.toInt();
    }
    return null;
  }

  double? get remoteAvgGross {
    final s = arMemberStats;
    if (s == null) return null;
    for (final k in [
      'avg_gross_speed',
      'average_gross_speed',
      'avg_gross',
      'gross_speed_avg',
    ]) {
      final v = s[k];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  double? get remoteAvgNet {
    final s = arMemberStats;
    if (s == null) return null;
    for (final k in [
      'avg_net_speed',
      'average_net_speed',
      'avg_net',
      'net_speed_avg',
    ]) {
      final v = s[k];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  double? get remoteAvgAccuracy {
    final s = arMemberStats;
    if (s == null) return null;
    for (final k in [
      'avg_accuracy',
      'average_accuracy',
      'accuracy_avg',
    ]) {
      final v = s[k];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  // ─── Aggregates ─────────────────────────────────────────────────────────

  List<TypingSession> get today {
    final now = DateTime.now();
    return sessions
        .where((s) =>
            s.startedAt.year == now.year &&
            s.startedAt.month == now.month &&
            s.startedAt.day == now.day)
        .toList();
  }

  int get streak {
    if (sessions.isEmpty) return 0;
    final days = sessions
        .map((s) =>
            DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    var count = 0;
    var cursor =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final d in days) {
      if (d == cursor) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (d.isBefore(cursor)) {
        break;
      }
    }
    return count;
  }

  double get bestNetWpm {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.netWpm).reduce(max);
  }

  double get avgAccuracy {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.accuracy).reduce((a, b) => a + b) /
        sessions.length;
  }

  double get avgGross {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.wpm).reduce((a, b) => a + b) / sessions.length;
  }

  double get avgNet {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.netWpm).reduce((a, b) => a + b) /
        sessions.length;
  }

  int get qualifiedCount => sessions.where((s) => s.qualified).length;

  int get arSessionCount =>
      sessions.where((s) => s.source == 'ar' || s.id.startsWith('ar-')).length;

  int get todayMinutes =>
      today.fold<int>(0, (p, s) => p + (s.durationSec / 60).ceil());

  List<double> lastNNetWpm(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - i));
      final daySessions = sessions.where((s) =>
          s.startedAt.year == day.year &&
          s.startedAt.month == day.month &&
          s.startedAt.day == day.day);
      if (daySessions.isEmpty) return 0;
      return daySessions.map((s) => s.netWpm).reduce(max);
    });
  }

  List<double> lastNAccuracy(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - i));
      final daySessions = sessions
          .where((s) =>
              s.startedAt.year == day.year &&
              s.startedAt.month == day.month &&
              s.startedAt.day == day.day)
          .toList();
      if (daySessions.isEmpty) return 0;
      return daySessions.map((s) => s.accuracy).reduce((a, b) => a + b) /
          daySessions.length;
    });
  }

  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    profile = profile.copyWith(darkMode: darkMode);
    AppColors.dark = darkMode;
    await _persistActive();
    notifyListeners();
  }

  List<double> last7NetWpm() => lastNNetWpm(7);

  List<LeaderboardEntry> weeklyBoard() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final mine = sessions.where((s) => s.startedAt.isAfter(weekAgo)).toList();
    final myBest = mine.isEmpty ? 0.0 : mine.map((s) => s.netWpm).reduce(max);
    final myAcc = mine.isEmpty
        ? 0.0
        : mine.map((s) => s.accuracy).reduce((a, b) => a + b) / mine.length;

    final rng = Random(42);
    final names = [
      ['Aarav Mishra', '@aarav'],
      ['Isha Verma', '@isha'],
      ['Rohan Gupta', '@rohan'],
      ['Neha Singh', '@neha'],
      ['Kabir Joshi', '@kabir'],
      ['Ananya Rao', '@ananya'],
      ['Vikram Yadav', '@vikram'],
      ['Meera Shah', '@meera'],
      ['Dev Patel', '@dev'],
      ['Sara Khan', '@sara'],
    ];

    final list = <LeaderboardEntry>[
      LeaderboardEntry(
        userId: profile.id,
        name: profile.name,
        handle: profile.handle,
        bestNetWpm: myBest,
        accuracy: myAcc,
        sessions: mine.length,
        streak: streak,
        isYou: true,
      ),
      ...List.generate(names.length, (i) {
        final base = 28 + rng.nextInt(28) + rng.nextDouble();
        return LeaderboardEntry(
          userId: 'bot-$i',
          name: names[i][0],
          handle: names[i][1],
          bestNetWpm: base,
          accuracy: 92 + rng.nextDouble() * 7,
          sessions: 4 + rng.nextInt(18),
          streak: rng.nextInt(14),
        );
      }),
    ]..sort((a, b) => b.bestNetWpm.compareTo(a.bestNetWpm));
    return list;
  }

  static TypingSession buildSession({
    required int allottedSec,
    required int timeTakenSec,
    required String language,
    required String mode,
    required String examTitle,
    required String passageTitle,
    required String expected,
    required String typed,
    required int backspaceCount,
    required int targetWpm,
    int errorAllowance = 5,
    double penaltyMultiplier = 5,
    bool useDurationForSpeed = false,
    bool keystrokeWordFormula = true,
    int? liveRank,
    int? liveField,
  }) {
    final score = Scoring.evaluate(
      expected: expected,
      typed: typed,
      durationSec: allottedSec,
      timeTakenSec: timeTakenSec,
      targetWpm: targetWpm,
      errorAllowance: errorAllowance,
      penaltyMultiplier: penaltyMultiplier,
      useDurationForSpeed: useDurationForSpeed,
      keystrokeWordFormula: keystrokeWordFormula,
    );
    return TypingSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      durationSec: allottedSec,
      timeTakenSec: timeTakenSec,
      language: language,
      mode: mode,
      examTitle: examTitle,
      passageTitle: passageTitle,
      keystrokesGiven: expected.length,
      typedChars: score.typedChars,
      correctChars: score.correctChars,
      errors: score.errors,
      wordsTyped: score.wordsTyped,
      fullMistakes: score.fullMistakes,
      halfMistakes: score.halfMistakes,
      totalWrongWords: score.totalWrongWords,
      netWrongWords: score.netWrongWords,
      backspaceCount: backspaceCount,
      wpm: score.grossWpm,
      netWpm: max(score.netWpm, 0),
      accuracy: score.accuracy,
      qualified: score.qualified,
      formulaNote: score.formulaNote,
      targetWpm: targetWpm,
      expectedText: expected,
      typedText: typed,
      source: 'local',
      liveRank: liveRank,
      liveField: liveField,
    );
  }

  /// Illustrative UPSSSC-style history (mirrors typical AR member patterns).
  static List<TypingSession> seedHistory() {
    TypingSession row({
      required String id,
      required DateTime at,
      required String exam,
      required String passage,
      required String lang,
      required int keys,
      required int given,
      required double gross,
      required double net,
      required int target,
      required int full,
      required int half,
      required int backspaces,
      required int timeTaken,
      int duration = 300,
      double accuracy = 99,
    }) {
      final words = keys / 5.0;
      final totalWrong = full + half * 0.5;
      final qualified = net >= target;
      return TypingSession(
        id: id,
        startedAt: at,
        durationSec: duration,
        timeTakenSec: timeTaken,
        language: lang,
        mode: 'practice',
        examTitle: exam,
        passageTitle: passage,
        keystrokesGiven: given,
        typedChars: keys,
        correctChars: (keys * accuracy / 100).round(),
        errors: max(0, keys - (keys * accuracy / 100).round()),
        wordsTyped: words,
        fullMistakes: full,
        halfMistakes: half,
        totalWrongWords: totalWrong,
        netWrongWords: 0,
        backspaceCount: backspaces,
        wpm: gross,
        netWpm: net,
        accuracy: accuracy,
        qualified: qualified,
        formulaNote:
            'Net Correct Words = ${words.toStringAsFixed(1)} − ((${totalWrong.toStringAsFixed(1)} − 5) + (${totalWrong.toStringAsFixed(1)} − 5) × 5)   [E ≤ allowance → no penalty]',
        targetWpm: target,
        source: 'local',
      );
    }

    const en = 'UPSSSC Assistants English Typing Test';
    const hi = 'UPSSSC Assistants Hindi Typing Test';

    return [
      row(
        id: 'seed-1',
        at: DateTime(2026, 9, 27, 18, 40),
        exam: en,
        passage: 'India From Implementor to Innovator',
        lang: 'en',
        keys: 947,
        given: 1500,
        gross: 37.88,
        net: 37.88,
        target: 30,
        full: 2,
        half: 2,
        backspaces: 26,
        timeTaken: 299,
      ),
      row(
        id: 'seed-2',
        at: DateTime(2026, 9, 26, 20, 10),
        exam: en,
        passage: "Madurai's Meenakshi Temple",
        lang: 'en',
        keys: 1025,
        given: 1500,
        gross: 41.2,
        net: 41.0,
        target: 30,
        full: 1,
        half: 1,
        backspaces: 18,
        timeTaken: 298,
        accuracy: 99.2,
      ),
      row(
        id: 'seed-3',
        at: DateTime(2026, 9, 25, 19, 5),
        exam: en,
        passage: 'The Biology of Bone Aging',
        lang: 'en',
        keys: 1100,
        given: 1500,
        gross: 44.1,
        net: 43.8,
        target: 30,
        full: 0,
        half: 2,
        backspaces: 14,
        timeTaken: 297,
        accuracy: 99.5,
      ),
      row(
        id: 'seed-4',
        at: DateTime(2026, 9, 24, 17, 30),
        exam: en,
        passage: 'Mirzapur - A Pre-Historic Haven',
        lang: 'en',
        keys: 980,
        given: 1500,
        gross: 39.4,
        net: 39.2,
        target: 30,
        full: 1,
        half: 0,
        backspaces: 22,
        timeTaken: 299,
      ),
      row(
        id: 'seed-5',
        at: DateTime(2026, 9, 23, 21, 0),
        exam: en,
        passage: 'Chronic Stress',
        lang: 'en',
        keys: 955,
        given: 1500,
        gross: 38.3,
        net: 38.1,
        target: 30,
        full: 2,
        half: 1,
        backspaces: 30,
        timeTaken: 298,
        accuracy: 98.8,
      ),
      row(
        id: 'seed-6',
        at: DateTime(2026, 9, 22, 18, 15),
        exam: hi,
        passage: 'Sushasan Aur Nagarik',
        lang: 'hi',
        keys: 780,
        given: 1250,
        gross: 31.4,
        net: 31.2,
        target: 25,
        full: 1,
        half: 1,
        backspaces: 20,
        timeTaken: 298,
        accuracy: 99.1,
      ),
      row(
        id: 'seed-7',
        at: DateTime(2026, 9, 21, 16, 45),
        exam: hi,
        passage: 'Karyalay Anushasan',
        lang: 'hi',
        keys: 720,
        given: 1250,
        gross: 29.0,
        net: 28.6,
        target: 25,
        full: 2,
        half: 2,
        backspaces: 28,
        timeTaken: 299,
        accuracy: 98.7,
      ),
      row(
        id: 'seed-8',
        at: DateTime(2026, 9, 20, 19, 20),
        exam: en,
        passage: 'Rivers and Urban Memory',
        lang: 'en',
        keys: 1010,
        given: 1500,
        gross: 40.5,
        net: 40.3,
        target: 30,
        full: 0,
        half: 1,
        backspaces: 12,
        timeTaken: 298,
        accuracy: 99.4,
      ),
      row(
        id: 'seed-9',
        at: DateTime(2026, 9, 19, 15, 10),
        exam: en,
        passage: 'India From Implementor to Innovator',
        lang: 'en',
        keys: 930,
        given: 1500,
        gross: 37.2,
        net: 36.9,
        target: 30,
        full: 3,
        half: 0,
        backspaces: 24,
        timeTaken: 300,
        accuracy: 98.9,
      ),
      row(
        id: 'seed-10',
        at: DateTime(2026, 9, 18, 20, 40),
        exam: hi,
        passage: 'Sushasan Aur Nagarik',
        lang: 'hi',
        keys: 800,
        given: 1250,
        gross: 32.1,
        net: 31.8,
        target: 25,
        full: 1,
        half: 0,
        backspaces: 16,
        timeTaken: 297,
        accuracy: 99.3,
      ),
      row(
        id: 'seed-11',
        at: DateTime(2026, 9, 17, 18, 0),
        exam: en,
        passage: "Madurai's Meenakshi Temple",
        lang: 'en',
        keys: 890,
        given: 1500,
        gross: 35.7,
        net: 35.4,
        target: 30,
        full: 2,
        half: 1,
        backspaces: 19,
        timeTaken: 299,
      ),
      row(
        id: 'seed-12',
        at: DateTime(2026, 9, 16, 21, 30),
        exam: en,
        passage: 'The Biology of Bone Aging',
        lang: 'en',
        keys: 1050,
        given: 1500,
        gross: 42.0,
        net: 41.7,
        target: 30,
        full: 1,
        half: 0,
        backspaces: 11,
        timeTaken: 298,
        accuracy: 99.6,
      ),
      row(
        id: 'seed-13',
        at: DateTime(2026, 9, 15, 17, 50),
        exam: hi,
        passage: 'Karyalay Anushasan',
        lang: 'hi',
        keys: 710,
        given: 1250,
        gross: 28.5,
        net: 28.2,
        target: 25,
        full: 2,
        half: 1,
        backspaces: 25,
        timeTaken: 300,
        accuracy: 98.5,
      ),
      row(
        id: 'seed-14',
        at: DateTime(2026, 9, 14, 19, 5),
        exam: en,
        passage: 'Chronic Stress',
        lang: 'en',
        keys: 970,
        given: 1500,
        gross: 38.9,
        net: 38.6,
        target: 30,
        full: 1,
        half: 2,
        backspaces: 17,
        timeTaken: 298,
      ),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
}
