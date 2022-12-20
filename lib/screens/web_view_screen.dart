import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../services/notification_services.dart';

 const  fetchBackground = "fetchBackground";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case fetchBackground:
        print("Callback dispatcher called");
        NotificationService.showNotifications(title: "BeeperMD", body: "Latitude: {_currentPosition?.latitude} Longitude: {_currentPosition?.longitude}", fln: flutterLocalNotificationsPlugin);
        break;
    }
    return Future.value(true);
  });
}


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
  String? _currentAddress;
  Position? _currentPosition;
  Timer? countdownTimer;
  Duration myDuration = const Duration(days: 5);

 static const  fetchBackground = "fetchBackground";


  void startTimer() {
    countdownTimer =
        Timer.periodic(Duration(seconds: 5), (_) =>
            _getCurrentPosition().then((value) => NotificationService.showNotifications(title: "BeeperMD", body: "Latitude: ${_currentPosition?.latitude} Longitude: ${_currentPosition?.longitude}", fln: flutterLocalNotificationsPlugin)
        ));
  }

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

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high)
        .then((Position position) {
      setState(() => {_currentPosition = position});
      print("THE CURRENT POSITION IS $_currentPosition");
      print("THE CURRENT ADDRESS IS $_currentAddress");
    }).catchError((e) {
      debugPrint(e);
    });
  }



  @override
  void initState() {
    super.initState();
    _handleLocationPermission();
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    Workmanager().registerPeriodicTask(
      "1",
      fetchBackground,
      frequency: const Duration(seconds: 5),
    );

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
                   //     Workmanager().registerPeriodicTask(
                   //   "1",
                   //   fetchBackground,
                   //   frequency: Duration(seconds: 5),
                   // );
                   // _getCurrentPosition().then((value) => startTimer());
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
