import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/ar_api.dart';
import '../models/session.dart';
import 'notification_service.dart';

/// Isolate-safe AR Typing sync used by Workmanager + foreground service.
///
/// Uses the same SharedPreferences / secure-storage keys as [AppStore].
class BackgroundSync {
  BackgroundSync._();

  // Must match AppStore.
  static const kAccounts = 'tp_accounts';
  static const kActiveAccountId = 'tp_active_account_id';
  static const kBackgroundSync = 'tp_background_sync';
  static const kAppForeground = 'tp_app_foreground';

  static String profileKey(String id) => 'tp_profile_$id';
  static String sessionsKey(String id) => 'tp_sessions_$id';
  static String statsKey(String id) => 'tp_member_stats_$id';
  static String remoteProfileKey(String id) => 'tp_remote_profile_$id';

  static const periodicUniqueName = 'typepulse-periodic-sync';
  static const periodicTaskName = 'typepulsePeriodicSync';

  static Future<void> ensurePlugins() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
  }

  /// Sync active account: typedPassages + memberTypingStats (+ profile best-effort).
  /// Detects new session ids, persists, and optionally shows a local notification.
  static Future<int> run({bool notifyOnNew = true}) async {
    await ensurePlugins();
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getString(kActiveAccountId);
    if (accountId == null || accountId.isEmpty) return 0;

    final api = ArTypingApi(
      secure: const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    );
    await api.loadAccount(accountId);
    if (!api.isLoggedIn) return 0;

    final sessionsRaw = prefs.getString(sessionsKey(accountId));
    final previous = <TypingSession>[];
    if (sessionsRaw != null) {
      try {
        final list = jsonDecode(sessionsRaw) as List<dynamic>;
        previous.addAll(list.map(
            (e) => TypingSession.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    final previousIds = previous.map((s) => s.id).toSet();

    Map<String, dynamic>? remoteProfile;
    Map<String, dynamic>? memberStats;
    try {
      remoteProfile = await api.fetchProfile();
    } on ArApiException catch (e) {
      if (e.needsReauth) return 0;
    } catch (_) {}

    try {
      memberStats = await api.fetchMemberStats();
    } on ArApiException catch (e) {
      if (e.needsReauth) return 0;
    } catch (_) {}

    List<Map<String, dynamic>> remote;
    try {
      remote = await api.fetchAllHistory(maxPages: 15, pageSize: 100);
    } on ArApiException catch (e) {
      if (e.needsReauth) return 0;
      return 0;
    } catch (_) {
      return 0;
    }

    final mapped = remote.map(ArTypingApi.sessionFromRemote).toList();
    final localOnly = previous
        .where((s) => s.source != 'ar' && !s.id.startsWith('ar-'))
        .where((s) => !s.id.startsWith('seed-') && s.id != 'sample-upsssc')
        .toList();
    final merged = [...mapped, ...localOnly]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    await prefs.setString(
      sessionsKey(accountId),
      jsonEncode(merged.map((e) => e.toJson()).toList()),
    );
    if (memberStats != null) {
      await prefs.setString(statsKey(accountId), jsonEncode(memberStats));
    }
    if (remoteProfile != null) {
      await prefs.setString(
          remoteProfileKey(accountId), jsonEncode(remoteProfile));
    }

    if (notifyOnNew) {
      final newOnes =
          mapped.where((s) => !previousIds.contains(s.id)).toList();
      if (newOnes.isNotEmpty) {
        final latest = newOnes.first;
        final examShort = latest.examTitle.length > 28
            ? '${latest.examTitle.substring(0, 28)}…'
            : latest.examTitle;
        try {
          await NotificationService.instance.showNewResult(
            title: newOnes.length == 1
                ? 'New typing result'
                : '${newOnes.length} new typing results',
            body: '$examShort · Net ${latest.netWpm.toStringAsFixed(1)} WPM',
          );
        } catch (_) {}
      }
    }

    return mapped.length;
  }

  static Future<bool> isBackgroundSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBackgroundSync) ?? false;
  }

  static Future<void> setBackgroundSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBackgroundSync, enabled);
  }

  static Future<void> setAppForeground(bool foreground) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAppForeground, foreground);
  }

  static Future<bool> isAppForeground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAppForeground) ?? true;
  }
}
