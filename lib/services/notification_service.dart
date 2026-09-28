import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local device notifications for new AR Typing results.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const channelId = 'typepulse_results';
  static const channelName = 'Typing Results';
  static const channelDescription =
      'Alerts when new AR Typing results sync to this device';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.defaultImportance,
      ),
    );
    _ready = true;
  }

  /// Android 13+ runtime permission. Needs an Activity, so only call this from
  /// the UI isolate — never from Workmanager / the foreground service.
  Future<void> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showNewResult({
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    // Each isolate has its own memory, so derive ids from the clock instead
    // of a counter that would restart at 0 and overwrite older alerts.
    final nid = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000;
    await _plugin.show(
      nid,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_launcher',
        ),
      ),
    );
  }
}
