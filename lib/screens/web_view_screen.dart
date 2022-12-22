import 'dart:async';

import 'package:beepermd/services/background_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';

 const  fetchBackground = "fetchBackground";

final  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class WebViewContainer extends StatefulWidget {
  final url;
  const WebViewContainer(this.url);

  @override
  createState() => _WebViewContainerState(this.url);
}


class _WebViewContainerState extends State<WebViewContainer> {

  var _url;
  final _key = UniqueKey();
  bool isApiLoaded = true;
  _WebViewContainerState(this._url);

  static const snackBarDuration = Duration(seconds: 3);

  final snackBar = const SnackBar(
    content: Text('Press back again to leave'),
    duration: snackBarDuration,
  );

  DateTime? backButtonPressTime;

  Timer? countdownTimer;
  bool hasPermission = false;


 hasPermissionM()async{
   hasPermission = await _handleLocationPermission();
 }


  // Future<void> initializeService() async {
  //   final service = FlutterBackgroundService();
  //   /// OPTIONAL, using custom notification channel id
  //   const AndroidNotificationChannel channel = AndroidNotificationChannel(
  //     'my_foreground', // id
  //     'MY FOREGROUND SERVICE', // title
  //     description:
  //     'This channel is used for important notifications.', // description
  //     importance: Importance.low, // importance must be at low or higher level
  //   );
  //
  //   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //   FlutterLocalNotificationsPlugin();
  //   if (Platform.isIOS) {
  //     await flutterLocalNotificationsPlugin.initialize(
  //       const InitializationSettings(
  //         iOS: DarwinInitializationSettings(),
  //       ),
  //     );
  //   }
  //
  //   await flutterLocalNotificationsPlugin
  //       .resolvePlatformSpecificImplementation<
  //       AndroidFlutterLocalNotificationsPlugin>()
  //       ?.createNotificationChannel(channel);
  //
  //   await service.configure(
  //     androidConfiguration: AndroidConfiguration(
  //       onStart: onStart,
  //       autoStart: true,
  //       isForegroundMode: true,
  //       notificationChannelId: 'my_foreground',
  //       initialNotificationTitle: 'AWESOME SERVICE',
  //       initialNotificationContent: 'Initializing',
  //       foregroundServiceNotificationId: 888,
  //     ),
  //     iosConfiguration: IosConfiguration(
  //       // auto start service
  //       autoStart: true,
  //       // this will be executed when app is in foreground in separated isolate
  //       onForeground: onStart,
  //       // you have to enable background fetch capability on xcode project
  //       onBackground: onIosBackground,
  //     ),
  //   );
  //   service.startService();
  // }
  //
  // @pragma('vm:entry-point')
  // Future<bool> onIosBackground(ServiceInstance service) async {
  //   WidgetsFlutterBinding.ensureInitialized();
  //   DartPluginRegistrant.ensureInitialized();
  //   return true;
  // }
  //
  // @pragma('vm:entry-point')
  // static void onStart(ServiceInstance service) async {
  //   DartPluginRegistrant.ensureInitialized();
  //   /// OPTIONAL when use custom notification
  //   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //   FlutterLocalNotificationsPlugin();
  //   if (service is AndroidServiceInstance) {
  //     service.on('setAsForeground').listen((event) {
  //       service.setAsForegroundService();
  //     });
  //     service.on('setAsBackground').listen((event) {
  //       service.setAsBackgroundService();
  //     });
  //   }
  //   service.on('stopService').listen((event) {
  //     service.stopSelf();
  //   });
  //
  //   // bring to foreground
  //   Timer.periodic(const Duration(seconds: 5), (timer) async {
  //     if (service is AndroidServiceInstance) {
  //       if (await service.isForegroundService()) {
  //         var latitude;
  //         var longitude;
  //         await Geolocator.getCurrentPosition(
  //             desiredAccuracy: LocationAccuracy.high)
  //             .then((Position position) {
  //               latitude = position.latitude;
  //               longitude =position.longitude;
  //           // setState(() => {_currentPosition = position});
  //           print("THE CURRENT POSITION IS $position");
  //         }).catchError((e) {
  //           debugPrint(e);
  //         });
  //         /// OPTIONAL for use custom notification
  //         /// the notification id must be equals with AndroidConfiguration when you call configure() method.
  //         flutterLocalNotificationsPlugin.show(
  //           888,
  //           'COOL SERVICE',
  //           'Latitude ${latitude}',
  //           const NotificationDetails(
  //             android: AndroidNotificationDetails(
  //               'my_foreground',
  //               'MY FOREGROUND SERVICE',
  //               icon: 'ic_bg_service_small',
  //             ),
  //           ),
  //         );
  //         service.setForegroundNotificationInfo(
  //           title: "My App Service",
  //           content: "Latitude: $latitude}, Longitude : $longitude",
  //         );
  //       }
  //     }
  //     print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
  //     // test using external plugin
  //     final deviceInfo = DeviceInfoPlugin();
  //     String? device;
  //     if (Platform.isAndroid) {
  //       final androidInfo = await deviceInfo.androidInfo;
  //       device = androidInfo.model;
  //     }
  //
  //     if (Platform.isIOS) {
  //       final iosInfo = await deviceInfo.iosInfo;
  //       device = iosInfo.model;
  //     }
  //
  //     service.invoke(
  //       'update',
  //       {
  //         "current_date": DateTime.now().toIso8601String(),
  //         "device": device,
  //       },
  //     );
  //   });
  // }


  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }


  @override
  void initState() {
    super.initState();
    _handleLocationPermission();


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Builder(builder: (context) {
      return WillPopScope(
          onWillPop: ()=> handleWillPop(context),
          child: Stack(children: [
            WebView(
              key: _key,
              javascriptMode: JavascriptMode.unrestricted,
              initialUrl: _url,
              onPageFinished: (String url) {
               try{
                 print('Page finished loading: $url');
                 if(url == "http://54.163.228.123/app/schedule" )
                 {
                   BackgroundService().initializeService();
                 }
                 setState(() {
                   isApiLoaded = false;
                 });
               }catch(e){
                 print("THE ERROR IS $e");
               }

              }),
            isApiLoaded
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Stack(),
          ]),
      );
    }),
        );
  }

  Future<bool> handleWillPop(BuildContext context) async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        backButtonPressTime == null ||
            now.difference(backButtonPressTime!) > snackBarDuration;

    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return false;
    }
    return true;
  }
}
