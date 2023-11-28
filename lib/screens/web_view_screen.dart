import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:beepermd/services/background_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fetchBackground = "fetchBackground";
// const BASE_URL = 'http://54.163.228.123/'; //STAG_1
// const BASE_URL = 'http://54.205.107.161/'; //STAG_2
const BASE_URL = 'https://beepermd.com/'; //PROD
String _authStatus = 'Unknown';

class WebViewContainer extends StatefulWidget {
  const WebViewContainer({super.key});

  @override
  createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer>
    with WidgetsBindingObserver {
  final GlobalKey webViewKey = GlobalKey();
  PullToRefreshController? pullToRefreshController;
  InAppWebViewController? _webViewController;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  bool isVisible = false;
  bool isLoading = false;
  bool isPageValid = false;
  bool? serviceEnabled;
  bool isApiLoaded = true;
  var userIdForMobileApp;
  String? patientCookie = '';
  String? providerCookie = '';
  String? loggedInUserId = '';

  DateTime? backButtonPressTime;
  final CookieManager _cookieManager = CookieManager.instance();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  static const snackBarDuration = Duration(seconds: 3);
  var initialUrl = '${BASE_URL}patient';
  final snackBar = const SnackBar(
    content: Text('Press back again to leave'),
    duration: snackBarDuration,
  );

  getCookiesAndSaveInPref(String sessionId, String userType) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(userType, sessionId);
  }

  saveUserIDinPrefs(String userId) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString('userID', userId);
  }

  getUserIdPrefs() async {
    final SharedPreferences prefs = await _prefs;
    loggedInUserId = prefs.getString('userID') ?? '';
  }

  getPatientCookie() async {
    final SharedPreferences prefs = await _prefs;
    patientCookie = prefs.getString('patient') ?? '';
  }

  getProviderCookie() async {
    final SharedPreferences prefs = await _prefs;
    providerCookie = prefs.getString('provider') ?? '';
  }

  @override
  void dispose() {
    print("called dispose and closed background service");
    BackgroundService().stopService();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initConnectivity();
    getPatientCookie();
    getProviderCookie();
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
    checkPermissionStatus();
  }

  Future<bool> isUrlValid(String url) async {
    try {
      var response = await http.head(Uri.parse(url));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  Future<String> getCookie(url, userType) async {
    String sessionId = "";
    List<Cookie> cookies = await _cookieManager.getCookies(url: url!);
    for (var i = 0; i < cookies.length; i++) {
      if (cookies[i].name == 'JSESSIONID') {
        getCookiesAndSaveInPref(cookies[i].value, userType);
        sessionId = cookies[i].value;
        break;
      }
    }
    return sessionId;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    if (providerCookie!.isNotEmpty) {
      initialUrl = '${BASE_URL}app/schedule';
    } else if (patientCookie!.isNotEmpty) {
      initialUrl = '${BASE_URL}patient/#/home';
    }

    return Scaffold(
      body: Stack(
        children: [
          Builder(builder: (context) {
            return WillPopScope(
              onWillPop: () => handleWillPop(context),
              child: _connectionStatus.name != "none"
                  ? SafeArea(
                      child: InAppWebView(
                        key: webViewKey,
                        initialSettings: InAppWebViewSettings(
                            supportZoom: false,
                            useHybridComposition: true,
                            disableDefaultErrorPage: true),
                        pullToRefreshController: pullToRefreshController,
                        initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
                        onWebViewCreated: (InAppWebViewController controller) {
                          _webViewController = controller;
                        },
                        onLoadStop: (controller, url) async {
                          final SharedPreferences prefs = await _prefs;
                          setState(() {
                            isApiLoaded = false;
                            isVisible = false;
                            print("Load stop status $isVisible");
                          });
                          pullToRefreshController?.endRefreshing();
                          initConnectivity();
                          _connectivitySubscription = _connectivity
                              .onConnectivityChanged
                              .listen(_updateConnectionStatus);

                          if (url?.rawValue == "${BASE_URL}app/schedule") {
                            prefs.remove("patient");
                            patientCookie = '';
                            String sessionId = await getCookie(url, "provider");
                            var header = {"Cookie": "JSESSIONID=$sessionId"};
                            await _handleLocationPerm();
                            await _handleCameraPermission();
                            final response = await http.Client()
                                .get(Uri.parse(url!.rawValue), headers: header);
                            dom.Document document =
                                htmlparser.parse(response.body);
                            var data =
                                document.getElementById('userIdForMobileApp');
                            if (data?.attributes
                                    .containsValue('userIdForMobileApp') ??
                                false) {
                              userIdForMobileApp = data!.nodes[0];
                              await saveUserIDinPrefs(userIdForMobileApp.data);
                            }
                            getCurrentLocation();
                          } else if (url?.rawValue ==
                              "${BASE_URL}patient/#/home") {
                            prefs.remove("provider");
                            providerCookie = '';
                            String sessionId = await getCookie(url, "patient");
                            print("debugger in else if condition $sessionId");
                          }
                        },
                      ),
                    )
                  : const BeeperMDWidget(),
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
            child: const LinearProgressIndicator(
              color: Colors.blueAccent,
            ),
          ))
        ],
      ),
    );
  }

  ///******************** Location permission ***********************///

  Position? _currentPosition;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  void checkPermissionStatus() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    setState(() {
      _permissionStatus = status;
    });
  }

  ///******************** Location permission ***********************///

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

  Future<bool> _handleCameraPermission() async {
    // bool serviceEnabled;
    PermissionStatus result;
    if (Platform.isAndroid) {
      result = (await Permission.camera.request());
      if (result.isGranted) {
        // Either the permission was already granted before or the user just granted it.
        print("Camera Permission is granted");
        return true;
      } else {
        print("Camera Permission is denied");
        return false;
      }
    }
    return false;
  }

  _handleLocationPerm() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      showToast("Location permission granted");
      // Location permission granted, proceed with location-related tasks.
    } else if (status.isDenied) {
      showToast("Location permission denied");
      // Location permission denied. Show a message to the user.
    } else if (status.isPermanentlyDenied) {
      showToast("Location permission permanently denied");
      // Location permission permanently denied. Ask the user to go to settings and manually enable it.
    }
  }

  Future<void> initConnectivity() async {
    ConnectivityResult result;
    try {
      result = await _connectivity.checkConnectivity();
      setState(() {
        if (isApiLoaded) {
          if (result == ConnectivityResult.mobile) {
            isVisible = true;
          } else if (result == ConnectivityResult.wifi) {
            isVisible = true;
          } else {
            isVisible = false;
          }
        }
      });
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
      } else {
        // BackgroundService().initializeService();
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
      child: SizedBox(
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
      child: SizedBox(
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
