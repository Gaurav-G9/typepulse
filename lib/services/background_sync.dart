import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/ar_api.dart';
import '../models/ar_result.dart';
import 'notification_service.dart';

/// Isolate-safe AR Typing sync used by Workmanager + the foreground service.
/// Writes the same keys as [AppStore]: the raw Typing History rows.
class BackgroundSync {
  BackgroundSync._();

  static const kAccounts = 'tp_accounts';
  static const kActiveAccountId = 'tp_active_account_id';
  static const kBackgroundSync = 'tp_background_sync';
  static const kAppForeground = 'tp_app_foreground';

  static String historyKey(String id) => 'tp_history_$id';
  static String statsKey(String id) => 'tp_member_stats_$id';
  static String userInfoKey(String id) => 'tp_user_me_$id';
  static String remoteProfileKey(String id) => 'tp_remote_profile_$id';
  static String syncedAtKey(String id) => 'tp_synced_at_$id';

  /// Set when AR Typing ended this device's sign-in (read by the UI).
  static String sessionEndedKey(String id) => 'tp_session_ended_$id';

  /// Background isolates can't show the sign-in screen: record why and tell
  /// the user once with a notification.
  static Future<void> _sessionEnded(
      SharedPreferences prefs, String accountId) async {
    if (prefs.getBool(sessionEndedKey(accountId)) ?? false) return;
    await prefs.setBool(sessionEndedKey(accountId), true);
    try {
      await NotificationService.instance.showNewResult(
        title: 'Signed out of AR Typing',
        body: 'This account signed in on another device. Open TypePulse and '
            'sign in again to keep syncing.',
      );
    } catch (_) {}
  }

  static const periodicUniqueName = 'typepulse-periodic-sync';
  static const periodicTaskName = 'typepulsePeriodicSync';

  static Future<void> ensurePlugins() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
  }

  /// Notification text for a result, e.g. "UPSSSC … · Net 39.6 WPM".
  static String resultSummary(ArResult r) {
    final exam = r.examTitle.length > 28
        ? '${r.examTitle.substring(0, 28)}…'
        : r.examTitle;
    final speed = r.netWpm != null
        ? 'Net ${r.netWpm!.toStringAsFixed(1)} WPM'
        : r.grossWpm != null
            ? 'Gross ${r.grossWpm!.toStringAsFixed(1)} WPM'
            : r.passageTitle;
    return '$exam · $speed';
  }

  static Set<String> _ids(String? raw) {
    if (raw == null) return {};
    try {
      final rows = jsonDecode(raw) as List<dynamic>;
      final ids = <String>{};
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row is Map<String, dynamic>) {
          ids.add(ArResult.fromRow(row, order: rows.length - i).id);
        }
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  /// Syncs the active account; shows a notification for new results.
  static Future<int> run({bool notifyOnNew = true}) async {
    await ensurePlugins();
    final prefs = await SharedPreferences.getInstance();
    // Long-lived isolates keep a stale copy of prefs; re-read first.
    await prefs.reload();
    final accountId = prefs.getString(kActiveAccountId);
    if (accountId == null || accountId.isEmpty) return 0;

    final api = ArTypingApi(
      secure: const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    );
    await api.loadAccount(accountId);
    if (!api.isLoggedIn) return 0;

    final previousIds = _ids(prefs.getString(historyKey(accountId)));

    Map<String, dynamic>? stats;
    try {
      stats = await api.fetchMemberStats();
    } on ArApiException catch (e) {
      if (e.needsReauth) {
        await _sessionEnded(prefs, accountId);
        return 0;
      }
    } catch (_) {}

    final List<Map<String, dynamic>> rows;
    try {
      rows = await api.fetchAllHistory(maxPages: 15, pageSize: 100);
    } on ArApiException catch (e) {
      if (e.needsReauth) await _sessionEnded(prefs, accountId);
      return 0;
    } catch (_) {
      return 0;
    }

    await prefs.reload();
    if (prefs.getString(kActiveAccountId) != accountId) return 0;
    await prefs.setString(historyKey(accountId), jsonEncode(rows));
    if (stats != null) {
      await prefs.setString(statsKey(accountId), jsonEncode(stats));
    }
    await prefs.setInt(
        syncedAtKey(accountId), DateTime.now().millisecondsSinceEpoch);

    if (notifyOnNew && previousIds.isNotEmpty) {
      final fresh = <ArResult>[];
      for (var i = 0; i < rows.length; i++) {
        final r = ArResult.fromRow(rows[i], order: rows.length - i);
        if (!previousIds.contains(r.id)) fresh.add(r);
      }
      fresh.sort((a, b) => b.date.compareTo(a.date));
      if (fresh.isNotEmpty) {
        try {
          await NotificationService.instance.showNewResult(
            title: fresh.length == 1
                ? 'New typing result'
                : '${fresh.length} new typing results',
            body: resultSummary(fresh.first),
          );
        } catch (_) {}
      }
    }
    return rows.length;
  }

  static Future<bool> isBackgroundSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
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
    await prefs.reload();
    return prefs.getBool(kAppForeground) ?? true;
  }
}
