import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  static Future initialize(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = AndroidInitializationSettings("mipmap/app_logo");
    var iOSInitialize = DarwinInitializationSettings();
    var initializationSettings =
        InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  static Future showNotifications(
      {var id,
      required String title,
      required String body,
      var payload,
      required FlutterLocalNotificationsPlugin fln}) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
          "You_can_name_it_whatever1",
            "channelName",
          playSound: true,
          importance: Importance.max,
          priority: Priority.high
    );

    var not = NotificationDetails(android: androidPlatformChannelSpecifics,iOS: DarwinNotificationDetails());
    await fln.show(0, title, body, not);
  }
}
