import 'dart:async';
import 'dart:collection';

import 'package:beepermd/services/background_services.dart';
import 'package:beepermd/services/html_parser_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fetchBackground = "fetchBackground";

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class WebViewContainer extends StatefulWidget {
  final url;

  const WebViewContainer(this.url);

  @override
  createState() => _WebViewContainerState(this.url);
}

class _WebViewContainerState extends State<WebViewContainer> {
  final GlobalKey webViewKey = GlobalKey();
  var _url;
  bool isApiLoaded = true;

  _WebViewContainerState(this._url);

  InAppWebViewController? _webViewController;
  CookieManager _cookieManager = CookieManager.instance();

  static const snackBarDuration = Duration(seconds: 3);

  final snackBar = const SnackBar(
    content: Text('Press back again to leave'),
    duration: snackBarDuration,
  );

  DateTime? backButtonPressTime;


  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
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
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }


  @override
  void initState() {
    super.initState();
    _handleLocationPermission();
  }

  getCookiesAndSaveInPref(String sessionId, WebUri url)async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Cookie1', sessionId);
    var session = await prefs.get('Cookie1');
    print("SESSION IN PREFV $session");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(builder: (context) {
        return WillPopScope(
          onWillPop: () => handleWillPop(context),
          child: Stack(children: [
            InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url:WebUri('http://54.163.228.123/app/login/authm/') ),
              onWebViewCreated: (InAppWebViewController controller) {
                _webViewController = controller;
              },
              initialUserScripts: UnmodifiableListView<UserScript>([]),
              onLoadStop: ( controller,  url) async {
                print("THE BASE URL OF BEEPER MD $url");
                setState(() {
                         isApiLoaded = false;
                       });
                List<Cookie> cookies = await _cookieManager.getCookies(url: url!);
                getCookiesAndSaveInPref(cookies[0].value,url);
                cookies.forEach((cookie) {
                  print(" THE COOKIES ${cookie.name} ${cookie.value}");
                });
                if(url.rawValue == "http://54.163.228.123/app/schedule"){
                    BackgroundService().initializeService();
                    HTMLParserService().parserMethod();
                }
                }
            ),
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
