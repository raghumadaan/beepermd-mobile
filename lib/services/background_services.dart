import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:background_location/background_location.dart';
import 'package:beepermd/core/data/remote/failed_request_manager.dart';
import 'package:beepermd/core/data/remote/rest_client.dart';
import 'package:beepermd/core/model/failed_request.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

const successStatusCodes = [200, 201];

class BackgroundService {
  Future<void> initializeService() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'notificationChannelId', // id
      'MY FOREGROUND SERVICE', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.low, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,

        notificationChannelId:
            "notificationChannelId", // this must match with notification channel you created above.
        initialNotificationTitle: 'AWESOME SERVICE',
        initialNotificationContent: 'Initializing',
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
    var isRunning = await service.isRunning();
    if (!isRunning) {
      service.startService();
    }
  }

  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    await FailedRequestManager()
        .initialize(); // Call initialize if not already done
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    FailedRequestManager().getFailedRequests().then((value) async {
      if (value.isNotEmpty) {
        for (var request in value) {
          try {
            final response = await RestClient().post(
              request.apiName,
              request.sessionID,
              request.lat,
              request.long,
              request.deviceId,
              request.timestamp,
            );

            if (successStatusCodes.contains(response!.statusCode)) {
              debugPrint("posted failed request: ${request.timestamp}");
              await FailedRequestManager().removeRequest(request);
            }
          } catch (e) {
            debugPrint("Failed Request retry failed: $e");
          }
        }
      }
    });
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    await FailedRequestManager()
        .initialize(); // Call initialize if not already done
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
        getCurrentLocation(true);
      }
    } else {
      if (service is IOSServiceInstance) {
        try {
          getCurrentLocation(true);
        } on Exception catch (e) {
          debugPrint("THE ERROR IN THE SERVICE $e");
        }
        // print('Latitude: $latitude, Longitude : $longitude ');
      }
    }

    FailedRequestManager().getFailedRequests().then((value) async {
      if (value.isNotEmpty) {
        for (var request in value) {
          try {
            final response = await RestClient().post(
              request.apiName,
              request.sessionID,
              request.lat,
              request.long,
              request.deviceId,
              request.timestamp,
            );

            if (successStatusCodes.contains(response!.statusCode)) {
              debugPrint("posted failed request: ${request.timestamp}");
              await FailedRequestManager().removeRequest(request);
            }
          } catch (e) {
            debugPrint("Failed Request retry failed: $e");
          }
        }
      }
    });

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
    getCurrentLocation(false);
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
      debugPrint("Logging Out");
    } else {
      // service.startService();
    }
  }
}

Future<void> getCurrentLocation(bool isLoggedIn) async {
  FailedRequestManager().clearAllRequests();
  final prefs = await SharedPreferences.getInstance();
  var session = prefs.get('provider');
  var userId = prefs.get('userID');
  const locationUpdateInterval = 30;
  Connectivity connectivity = Connectivity();
  ConnectivityResult result;
  Timer? timer;
  try {
    result = (await connectivity.checkConnectivity()) as ConnectivityResult;
  } on PlatformException catch (e) {
    developer.log('Couldn\'t check connectivity status', error: e);
    return;
  }

  if (isLoggedIn == true) {
    timer = Timer.periodic(const Duration(seconds: locationUpdateInterval),
        (timer) async {
      if (result.name != 'none') {
        try {
          var position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high)
              .onError((error, stackTrace) {
            if (Platform.isAndroid) {
              FlutterBackgroundService().invoke('stopService');
            }
            debugPrint("THE ERROR IN THE SERVICE $error");
            throw error as Object;
          });
          debugPrint("THE CURRENT POSITION IS $position");

          if (!position.isBlank!) {
            try {
              RestClient().post(
                'user/saveLatLong2',
                session,
                position.latitude,
                position.longitude,
                userId,
              );
            } catch (e) {
              FailedRequestManager().saveRequest(
                FailedRequest(
                  apiName: 'user/saveLatLong2',
                  sessionID: "$session",
                  lat: position.latitude,
                  long: position.longitude,
                  deviceId: userId.toString(),
                  timestamp: DateTime.now(),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint("Error fetching the location: $e");
        }
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
  } else {
    if (timer != null) {
      timer.cancel();
      timer = null;
    }
  }
}

void showToast(String message) {
  Fluttertoast.showToast(
      msg: message,
      webPosition: "right",
      webShowClose: true,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0);
}
