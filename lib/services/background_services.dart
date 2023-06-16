import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:background_location/background_location.dart';
import 'package:beepermd/core/data/remote/rest_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundService {
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
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
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    } else if (service is IOSServiceInstance) {
      service.on('start').listen((event) {
        service.invoke('start');
      });
      service.on('setBackgroundFetchResult').listen((event) {
        service.invoke('setBackgroundFetchResult');
      });
    }
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.on('setAsForeground').listen((event) {
          FlutterBackgroundService().invoke("setAsForeground");
        });
        service.on('setAsBackground').listen((event) {
          FlutterBackgroundService().invoke("setAsBackground");
        });
        getCurrentLocation();
      }
    } else {
      if (service is IOSServiceInstance) {
        try {
          getCurrentLocation();
        } on Exception catch (e) {
          debugPrint("THE ERROR IN THE SERVICE $e");
        }
        // print('Latitude: $latitude, Longitude : $longitude ');
      }
    }
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
  }

  Future<void> stopService() async {
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

Future<void> getCurrentLocation() async {
  final prefs = await SharedPreferences.getInstance();
  var session = prefs.get('Cookie1');
  var userId = prefs.get('userID');

  Connectivity _connectivity = Connectivity();
  ConnectivityResult result;
  try {
    result = await _connectivity.checkConnectivity();
  } on PlatformException catch (e) {
    developer.log('Couldn\'t check connectivity status', error: e);
    return;
  }

  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position? position) {
    print("THE CURRENT POSITION IS $position");
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (result.name != 'none') {
        RestClient().post('user/saveLatLong', session, position?.latitude,
            position?.longitude, userId);
      } else {
        Fluttertoast.showToast(
            msg: result.name == 'none' ? "No Internet" : 'Internet',
            webPosition: "right",
            webShowClose: true,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: result.name == 'none' ? Colors.red : Colors.green,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    });
  }).onError((e) {
    if (Platform.isAndroid) {
      FlutterBackgroundService().invoke('stopService');
    }
    debugPrint("THE ERROR IN THE SERVICE $e");
  });
}
