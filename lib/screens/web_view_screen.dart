import 'dart:async';
import 'dart:collection';

import 'package:beepermd/services/background_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as htmlparser;
import 'dart:developer' as developer;

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
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final GlobalKey webViewKey = GlobalKey();
  var _url;
  bool isVisible = true;

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
              'Please allow the location permission to use the app')));
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

  getCookiesAndSaveInPref(String sessionId, WebUri url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Cookie1', sessionId);
  }

  saveUserIDinPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userID', userId);
  }

  Future<void> initConnectivity() async {
    ConnectivityResult result;
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      developer.log('Couldn\'t check connectivity status', error: e);
      return;
    }

    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _connectionStatus = result;
      if (_connectionStatus.name == 'none') {
        BackgroundService().stopService();
      } else {
        BackgroundService().initializeService();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    Future.delayed(Duration(milliseconds: 1500)).then((value) {
      isVisible = false;
      return isVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Builder(builder: (context) {
              return WillPopScope(
                onWillPop: () => handleWillPop(context),
                child: _connectionStatus.name != "none"
                    ? Stack(
                        children: [
                          InAppWebView(
                            key: webViewKey,
                            initialUrlRequest: URLRequest(
                                url: WebUri(
                                    'http://54.163.228.123/app/login/authm/')),
                            onWebViewCreated:
                                (InAppWebViewController controller) {
                              _webViewController = controller;
                            },
                            initialUserScripts:
                                UnmodifiableListView<UserScript>([]),
                            onLoadStop: (controller, url) async {
                              setState(() {
                                isApiLoaded = false;
                              });
                              initConnectivity();
                              _connectivitySubscription = _connectivity
                                  .onConnectivityChanged
                                  .listen(_updateConnectionStatus);
                              List<Cookie> cookies =
                                  await _cookieManager.getCookies(url: url!);
                              getCookiesAndSaveInPref(cookies[0].value, url);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              var sessionID = prefs.getString('Cookie1');
                              var header = {"Cookie": "JSESSIONID=$sessionID"};
                              if (url.rawValue ==
                                  "http://54.163.228.123/app/schedule") {
                                _handleLocationPermission();
                                final response = await http.Client().get(
                                    Uri.parse(url.rawValue),
                                    headers: header);
                                print("THE RESPONSE OF Data ${response.body}");
                                dom.Document document =
                                    htmlparser.parse(response.body);
                                var data = document
                                    .getElementById('userIdForMobileApp');
                                if (data!.attributes
                                    .containsValue('userIdForMobileApp')) {
                                  userIdForMobileApp =
                                      data.attributes['data-value'];
                                  saveUserIDinPrefs(userIdForMobileApp);
                                }
                                BackgroundService().initializeService();
                              } else {
                                BackgroundService().stopService();
                              }
                            },
                          ),
                        ],
                      )
                    : BeeperMDWidget(),
              );
            }),
          ),
          Positioned(
            child: Visibility(
              visible: isVisible,
              child: SafeArea(
                child: Container(
                  height: size.height,
                  width: size.width,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image:
                          AssetImage("assets/images/splahs_background_01.jpg"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      "assets/images/beeper_logo.png",
                      scale: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

class BeeperMDWidget extends StatelessWidget {
  const BeeperMDWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
            // image: DecorationImage(
            //     image: AssetImage("assets/images/splash_logo_final.jpg"),
            //     fit: BoxFit.cover
            // ),
            ),
        child: Column(
          children: [
            SizedBox(
              height: size.height * 0.13,
            ),
            Image.asset(
              "assets/images/beeper_logo.png",
              scale: 3,
            ),
            SizedBox(
              height: size.height * 0.06,
            ),
            Image.asset(
              "assets/images/no_internet.png",
              scale: 3,
            ),
            SizedBox(
              height: size.height * 0.03,
            ),
            const Text(
              "Oops!",
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 40),
            ),
            SizedBox(
              height: size.height * 0.02,
            ),
            const Text(
              "No Internet\nConnection",
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  fontSize: 20),
            )
          ],
        ),
      ),
    );
  }
}