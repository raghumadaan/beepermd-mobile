// ignore_for_file: unused_local_variable

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  "High Importance Notifcations",
  description: "This channel is used important notification",
  groupId: "Notification_group",
);

var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  channel.id,
  channel.name,
  channelDescription: channel.description,
  importance: Importance.max,
  priority: Priority.high,
  ticker: 'ticker',
  groupKey: channel.groupId,
  setAsGroupSummary: true,
);

class FirebaseNotificationService {
  // get fcm token
  static Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  static init() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.authorized)
      print('User granted permission');
    if (settings.authorizationStatus == AuthorizationStatus.provisional)
      print('User granted provisional permission');
    if (settings.authorizationStatus == AuthorizationStatus.denied)
      print('User declined or has not accepted permission');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('onMessage: $message');
      _handleNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('onMessageOpenedApp: ${message.data.toString()}');
    });

    FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);

    print(await getFCMToken());
  }

  static Future<void> _handleNotification(RemoteMessage message) async {
    print('handleNotification, ${message.data.toString()}');
    String title = message.notification?.title ?? '';
    String body = message.notification?.body ?? '';

    if (message.data.isNotEmpty) {
      title = title == '' ? message.data['title'] : title;
      body = body == '' ? message.data['body'] : body;
    }

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('notification_icon');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
              onDidReceiveLocalNotification: onDidReceiveLocalNotification);

      const InitializationSettings initializationSettings =
          InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsDarwin);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings,
          onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

      var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
      var platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
          message.hashCode, title, body, platformChannelSpecifics,
          payload: jsonEncode(message.data));
    } catch (e) {
      print('myMessageHandlerERROR, ${e.toString()}');
    }
  }
}

Future<void> onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload == null) return;

  Map<String, dynamic> data = jsonDecode(payload);
}

Future<void> onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) async {
  print('onDidReceiveLocalNotification, payload: $payload');
  if (payload == null) return;

  Map<String, dynamic> data = jsonDecode(payload);
}

@pragma('vm:entry-point')
Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  print('myBackgroundMessageHandler, ${message.data.toString()}');
}

didLocalNotificationLaunchApp() async {
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    print('didNotificationLaunchApp');
    final String? payload =
        notificationAppLaunchDetails?.notificationResponse?.payload;
    if (payload == null) return;

    Map<String, dynamic> data = jsonDecode(payload);
  }
}

didFirebaseNotificationLaunchApp() async {
  final RemoteMessage? message =
      await FirebaseMessaging.instance.getInitialMessage();
  if (message == null) return;
}
