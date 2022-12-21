// import 'dart:ui';
//
// import 'package:flutter_background_service/flutter_background_service.dart';
//
// class FlutterBackgroundServices1{
//
//   static Future<void> backgroundService() async {
//     final service = FlutterBackgroundService();
//     await service.configure(
//       androidConfiguration: AndroidConfiguration(
//         onStart: onStart,
//         autoStart: true,
//         isForegroundMode: true,
//       ),
//       iosConfiguration: IosConfiguration(
//         autoStart: true,
//         onForeground: onStart,
//         onBackground: onIosBackground,
//       ),
//     );
//     service.startService();
//   }
//
//
//   onStart(ServiceInstance service) async {
//     DartPluginRegistrant.ensureInitialized();
//     if (service is AndroidServiceInstance) {
//       service.on('setAsForeground').listen((event) {
//         service.setAsForegroundService();
//       });
//       service.on('setAsBackground').listen((event) {
//         service.setAsBackgroundService();
//       });
//     }
//     service.on('stopService').listen((event) {
//       service.stopSelf();
//     });
//   }
// }