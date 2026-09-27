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
  int _nid = 0;

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
    await androidPlugin?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> showNewResult({
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    _nid = (_nid + 1) % 100000;
    await _plugin.show(
      _nid,
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
