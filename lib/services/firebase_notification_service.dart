// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../screens/web_view_screen.dart';

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
    final apnsToken = await _firebaseMessaging.getAPNSToken();
    if (apnsToken == null) {
      await Future<void>.delayed(
        const Duration(
          seconds: 3,
        ),
      );
    }
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
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }
    if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    }
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('User declined or has not accepted permission');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('onMessage: $message');
      _handleNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('onMessageOpenedApp: ${message.data.toString()}');

      Get.to(WebViewContainer(
        url: message.data['url'],
      ));
    });

    FirebaseMessaging.instance.getInitialMessage().then((value) {
      if (value != null) {
        _handleNotification(value);
      }
    });
    FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);

    FirebaseMessaging.instance.subscribeToTopic('testData');
  }

  static generateNotification(id, title, body, message,
      NotificationDetails notificationDetails, payload) async {
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
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            onDidReceiveBackgroundNotificationResponse);

    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        message.hashCode, title, body, platformChannelSpecifics,
        payload: jsonEncode(message.data));
  }

  static Future<void> _handleNotification(RemoteMessage message) async {
    debugPrint('handleNotification, ${message.data.toString()}');
    String title = message.notification?.title ?? '';
    String body = message.notification?.body ?? '';
    String dataUrl = '';

    if (message.data.isNotEmpty) {
      title = title == '' ? message.data['title'] : title;
      body = body == '' ? message.data['body'] : body;
      dataUrl = message.data['url'];
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
          onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
          onDidReceiveBackgroundNotificationResponse:
              onDidReceiveBackgroundNotificationResponse);

      var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
      var platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
          message.hashCode, title, body, platformChannelSpecifics,
          payload: jsonEncode(message.data));
    } catch (e) {
      debugPrint('myMessageHandlerERROR, ${e.toString()}');
    }
  }
}

Future<void> onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload == null) return;

  Map<String, dynamic> data = jsonDecode(payload);

  Get.to(WebViewContainer(
    url: data['url'],
  ));
}

Future<void> onDidReceiveBackgroundNotificationResponse(
    NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload == null) return;

  Map<String, dynamic> data = jsonDecode(payload);

  Get.to(WebViewContainer(
    url: data['url'],
  ));
}

Future<void> onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) async {
  debugPrint('onDidReceiveLocalNotification, payload: $payload');
  if (payload == null) return;

  Map<String, dynamic> data = jsonDecode(payload);
}

@pragma('vm:entry-point')
Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('myBackgroundMessageHandler, ${message.data.toString()}');
}

didLocalNotificationLaunchApp() async {
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    debugPrint('didNotificationLaunchApp');
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
