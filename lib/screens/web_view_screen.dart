import 'dart:async';
import 'dart:io';

import 'package:beepermd/services/background_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  @override
  createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  final GlobalKey webViewKey = GlobalKey();

  PullToRefreshController? pullToRefreshController;
  InAppWebViewController? _webViewController;

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  bool isVisible = true;
  bool isLoading = false;
  bool isPageValid = false;

  bool isApiLoaded = true;
  var userIdForMobileApp;
  DateTime? backButtonPressTime;
  CookieManager _cookieManager = CookieManager.instance();

  static const snackBarDuration = Duration(seconds: 3);

  final snackBar = const SnackBar(
    content: Text('Press back again to leave'),
    duration: snackBarDuration,
  );

  getCookiesAndSaveInPref(String sessionId, WebUri url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Cookie1', sessionId);
  }

  saveUserIDinPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userID', userId);
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 1500)).then((value) {
      setState(() {
        isVisible = false;
      });
      return isVisible;
    });
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
            color: Colors.blueAccent,
            enabled: true,
            backgroundColor: Colors.white),
        onRefresh: () async {
          if (Platform.isAndroid) {
            _webViewController?.reload();
          } else if (Platform.isIOS) {
            _webViewController?.loadUrl(
                urlRequest:
                    URLRequest(url: await _webViewController?.getUrl()));
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Builder(builder: (context) {
              return WillPopScope(
                onWillPop: () => handleWillPop(context),
                child: _connectionStatus.name != "none"
                    ? InAppWebView(
                        key: webViewKey,
                        initialSettings: InAppWebViewSettings(
                            supportZoom: false, useHybridComposition: true,
                        disableDefaultErrorPage: true),
                        pullToRefreshController: pullToRefreshController,

                        initialUrlRequest: URLRequest(
                            url: WebUri(
                                'http://54.163.228.123/app/login')),
                        onWebViewCreated: (InAppWebViewController controller) {
                          _webViewController = controller;
                        },

                        onLoadStop: (controller, url) async {
                          setState(() {
                            isApiLoaded = false;
                              if (url?.hasAbsolutePath==true) {
                                isPageValid = false;
                              }
                              else{
                                isPageValid = true;
                              }
                          });
                          initConnectivity();
                          _connectivitySubscription = _connectivity
                              .onConnectivityChanged
                              .listen(_updateConnectionStatus);
                          List<Cookie> cookies =
                              await _cookieManager.getCookies(url: url!);
                          getCookiesAndSaveInPref(cookies[0].value, url);
                          final prefs = await SharedPreferences.getInstance();
                          var sessionID = prefs.getString('Cookie1');
                          var header = {"Cookie": "JSESSIONID=$sessionID"};
                          if (url.rawValue ==
                              "http://54.163.228.123/app/schedule") {
                            _handleLocationPermission();
                            final response = await http.Client()
                                .get(Uri.parse(url.rawValue), headers: header);
                            dom.Document document =
                                htmlparser.parse(response.body);
                            var data =
                                document.getElementById('userIdForMobileApp');
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

                        )
                    : BeeperMDWidget(),
              );
            }),
            Positioned(
              child: Visibility(
                visible: isVisible,
                child: SafeArea(
                  child: Container(
                    height: size.height,
                    width: size.width,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                            "assets/images/splahs_background_01.jpg"),
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
            Positioned(
              child: Visibility(
                visible: isPageValid,
                child: const SafeArea(
                  child: BeeperMDWidget2(),
                ),
              ),
            ),
            Positioned(
                child: Visibility(
              visible: isLoading,
              child: LinearProgressIndicator(
                color: Colors.blueAccent,
              ),
            ))
          ],
        ),
      ),
    );
  }

  Future<bool> handleWillPop(BuildContext context) async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        backButtonPressTime == null ||
            now.difference(backButtonPressTime!) > snackBarDuration;
    if (await _webViewController!.canGoBack()) {
      _webViewController?.goBack();
      return false;
    } else if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return false;
    }
    return true;
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please allow the location permission to use the app')));
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

class BeeperMDWidget2 extends StatelessWidget {
  const BeeperMDWidget2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Container(
        height: size.height,
        width: size.width,
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
              "assets/images/error.png",
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
              "We can't find that \nPage",
              textAlign: TextAlign.center,
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
