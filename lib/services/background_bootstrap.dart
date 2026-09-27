import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'background_sync.dart';
import 'notification_service.dart';

/// Workmanager (~15 min OS minimum) + optional continuous FGS (~30s) bootstrap.
class BackgroundBootstrap {
  BackgroundBootstrap._();

  static const syncChannelId = 'typepulse_sync';
  static const syncChannelName = 'Background Sync';
  static const syncNotificationId = 88001;

  static bool _configured = false;

  /// Call once from [main] before [runApp].
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_configured) return;

    await NotificationService.instance.init();
    await _ensureSyncChannel();

    await Workmanager().initialize(workmanagerCallbackDispatcher);

    final service = FlutterBackgroundService();
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceOnStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceOnStart,
        autoStart: false,
        // Android 14+/15 forbid starting a dataSync FGS from BOOT_COMPLETED
        // (ForegroundServiceStartNotAllowedException). Workmanager already
        // survives reboots; the FGS resumes next time the app is opened.
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: syncChannelId,
        initialNotificationTitle: 'TypePulse is syncing',
        initialNotificationContent: 'Checking AR Typing for new results…',
        foregroundServiceNotificationId: syncNotificationId,
        foregroundServiceTypes: const [AndroidForegroundType.dataSync],
      ),
    );

    _configured = true;

    // Resume continuous FGS after process death if the user left the toggle on.
    final enabled = await BackgroundSync.isBackgroundSyncEnabled();
    if (enabled) {
      await startContinuousSync();
    }
  }

  static Future<void> _ensureSyncChannel() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        syncChannelId,
        syncChannelName,
        description:
            'Ongoing notification while TypePulse syncs in the background',
        importance: Importance.low,
      ),
    );
  }

  /// Schedule Android WorkManager periodic sync (OS enforces ~15 min minimum).
  static Future<void> schedulePeriodicSync() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().registerPeriodicTask(
        BackgroundSync.periodicUniqueName,
        BackgroundSync.periodicTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  static Future<void> cancelPeriodicSync() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().cancelByUniqueName(BackgroundSync.periodicUniqueName);
    } catch (_) {}
  }

  /// Start low-priority FGS with ~30s polling ("TypePulse is syncing").
  static Future<void> startContinuousSync() async {
    if (!Platform.isAndroid) return;
    await BackgroundSync.setBackgroundSyncEnabled(true);
    try {
      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (!running) {
        await service.startService();
      }
    } catch (_) {
      // Android 12+ refuses to start a foreground service while the app is in
      // the background; it will start the next time the app is resumed.
    }
  }

  static Future<void> stopContinuousSync() async {
    if (!Platform.isAndroid) return;
    await BackgroundSync.setBackgroundSyncEnabled(false);
    try {
      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (running) {
        service.invoke('stop');
      }
    } catch (_) {}
  }

  /// Apply Profile toggle: enable FGS + keep Workmanager; or stop FGS only.
  static Future<void> setKeepSyncingInBackground(bool enabled) async {
    if (enabled) {
      await schedulePeriodicSync();
      await startContinuousSync();
    } else {
      await stopContinuousSync();
      // Periodic 15m Workmanager stays registered while an account is logged in.
    }
  }
}

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await BackgroundSync.run(notifyOnNew: true);
      return true;
    } catch (_) {
      return false;
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void backgroundServiceOnStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // Ongoing FGS notification text.
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'TypePulse is syncing',
      content: 'Checking AR Typing every ~30s',
    );
  }

  // Immediate pass, then every 30s while FGS is alive.
  try {
    final fg = await BackgroundSync.isAppForeground();
    if (!fg) {
      await BackgroundSync.run(notifyOnNew: true);
    }
  } catch (_) {}

  var busy = false;
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    // A slow network round-trip must not stack overlapping syncs.
    if (busy) return;
    busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // This isolate lives for hours; re-read values written by the UI.
      await prefs.reload();
      final stillWanted = prefs.getBool(BackgroundSync.kBackgroundSync) ?? false;
      if (!stillWanted) {
        timer.cancel();
        service.stopSelf();
        return;
      }
      // Foreground AppStore timer owns 30s sync while UI is visible.
      final fg = prefs.getBool(BackgroundSync.kAppForeground) ?? false;
      if (fg) return;
      await BackgroundSync.run(notifyOnNew: true);
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'TypePulse is syncing',
          content:
              'Last check ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (_) {
    } finally {
      busy = false;
    }
  });
}
