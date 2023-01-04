import 'dart:async';
import 'dart:collection';

import 'package:beepermd/services/background_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as htmlparser;


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
  _WebViewContainerState(this._url);

  bool isApiLoaded = true;
  var userIdForMobileApp;
  DateTime? backButtonPressTime;
  InAppWebViewController? _webViewController;
  CookieManager _cookieManager = CookieManager.instance();

  static const snackBarDuration = Duration(seconds: 3);

  final snackBar = const SnackBar(
    content: Text('Press back again to leave'),
    duration: snackBarDuration,
  );

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

  getCookiesAndSaveInPref(String sessionId, WebUri url)async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Cookie1', sessionId);
  }

  saveUserIDinPrefs(String userId)async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userID', userId);
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
                setState(() {
                         isApiLoaded = false;
                       });
                List<Cookie> cookies = await _cookieManager.getCookies(url: url!);
                getCookiesAndSaveInPref(cookies[0].value,url);
                final prefs = await SharedPreferences.getInstance();
                var sessionID =  prefs.getString('Cookie1');
                print("THE SESSION ID $sessionID");
                var header = {"Cookie":"JSESSIONID=$sessionID"};
                if(url.rawValue == "http://54.163.228.123/app/schedule"){
                  final response = await http.Client().get(Uri.parse(url.rawValue),headers:header);
                  print("THE RESPONSE OF Data ${response.body}");
                  dom.Document document = htmlparser.parse(response.body);
                  var data = document.getElementById('userIdForMobileApp');
                  if(data!.attributes.containsValue('userIdForMobileApp')){
                    userIdForMobileApp = data.attributes['data-value'];
                    saveUserIDinPrefs(userIdForMobileApp);
                  }
                    BackgroundService().initializeService();
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
