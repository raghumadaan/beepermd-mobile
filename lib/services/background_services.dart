import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:background_location/background_location.dart';
import 'package:beepermd/core/data/remote/rest_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;


class BackgroundService{

  ConnectivityResult _connectionStatus = ConnectivityResult.none;

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description:
      'This channel is used for important notifications.', // description
      importance: Importance.low, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'BeeperMD',

        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,
        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,
        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
    service.startService();
  }

  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    service.invoke('setAsBackground');
    DartPluginRegistrant.ensureInitialized();
    /// OPTIONAL when use custom notification
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // bring to foreground
    Timer.periodic(const Duration(seconds: 5), (timer) async {
       Connectivity _connectivity = Connectivity();
        ConnectivityResult result;
        try {
          result = await _connectivity.checkConnectivity();
        } on PlatformException catch (e) {
          developer.log('Couldn\'t check connectivity status', error: e);
          return;
        }
      if (service is AndroidServiceInstance) {

        if (await service.isForegroundService()) {
          service.on('setAsForeground').listen((event) {
            FlutterBackgroundService().invoke("setAsForeground");
          });
          service.on('setAsBackground').listen((event) {
            FlutterBackgroundService().invoke("setAsBackground");
          });
          var latitude;
          var longitude;
          final prefs = await SharedPreferences.getInstance();
          var session =  prefs.get('Cookie1');
          var userId= prefs.get('userID');
          await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
              .then((Position position) {
            latitude = position.latitude;
            longitude =position.longitude;
            print("THE CURRENT POSITION IS $position");
            if(result.name!='none'){
              RestClient().post('user/saveLatLong', session,latitude,longitude,userId);
            }
            else{
              Fluttertoast.showToast(
                  msg: "${result.name=='none'?"No Internet":'Internet'}",
                  webPosition: "right",
                  webShowClose: true,
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.TOP,
                  backgroundColor:result.name=='none'?Colors.red :Colors.green,
                  textColor: Colors.white,
                  fontSize: 16.0);
            }
          }).catchError((e) {

            debugPrint("THE ERROR IN THE SERIVICE $e");
          });
          /// OPTIONAL for use custom notification
          /// the notification id must be equals with AndroidConfiguration when you call configure() method.
          flutterLocalNotificationsPlugin.show(
            888,
            'BeeperMD',
            'Time:${DateTime.now()} Latitude $latitude',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'foreground',
                'Beeper MD',
                icon: '@mipmap/app_logo',
              ),
            ),
          );
          // print('Latitude: $latitude, Longitude : $longitude ');
          service.setForegroundNotificationInfo(
            title: "BeeperMD",
            content: "Time:${DateTime.now()} Latitude: $latitude, Longitude : $longitude  Time:${DateTime.now()}",
          );
        }


      }

       await BackgroundLocation.setAndroidNotification(
         title: 'Background service is running',
         message: 'Background location in progress',
         icon: '@mipmap/app_logo',
       );
       await BackgroundLocation.setAndroidConfiguration(1000);
       await BackgroundLocation.startLocationService();


      // test using external plugin
      final deviceInfo = DeviceInfoPlugin();
      String? device;
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        device = androidInfo.model;
      }

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        device = iosInfo.model;
      }

      service.invoke(
        'update',
        {
          "current_date": DateTime.now().toIso8601String(),
          "device": device,
        },
      );
    });
  }

  Future<void> stopService()async{
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
      print("Logging Out");
    } else {
      // service.startService();
    }
  }
}

Future<dynamic> getLocation()async{
  var data = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return data;
}