import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:beepermd/services/background_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fetchBackground = "fetchBackground";
const BASE_URL = 'http://54.163.228.123/'; //STAG
// const BASE_URL = 'https://beepermd.com/'; //PROD

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  DateTime? backButtonPressTime;
  final CookieManager _cookieManager = CookieManager.instance();
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
  void dispose() {
    print("called dispose and closed background service");
    BackgroundService().stopService();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
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
                        initialUrlRequest:
                            URLRequest(url: WebUri('${BASE_URL}patient')),
                        onWebViewCreated: (InAppWebViewController controller) {
                          _webViewController = controller;
                        },
                        onLoadStop: (controller, url) async {
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
                          List<Cookie> cookies =
                              await _cookieManager.getCookies(url: url!);
                          for (var i = 0; i < cookies.length; i++) {
                            if (cookies[i].name == 'JSESSIONID') {
                              getCookiesAndSaveInPref(cookies[i].value, url);
                            }
                          }

                          final prefs = await SharedPreferences.getInstance();
                          var sessionID = prefs.getString('Cookie1');
                          var header = {"Cookie": "JSESSIONID=$sessionID"};

                          if (url.rawValue == "${BASE_URL}app/schedule") {
                            final response = await http.Client()
                                .get(Uri.parse(url.rawValue), headers: header);
                            dom.Document document =
                                htmlparser.parse(response.body);
                            var data =
                                document.getElementById('userIdForMobileApp');
                            if (data?.attributes
                                    .containsValue('userIdForMobileApp') ??
                                false) {
                              userIdForMobileApp =
                                  data!.attributes['data-value'];
                              saveUserIDinPrefs(userIdForMobileApp);
                            }
                            await _handleLocationPerm();
                            await _handleCameraPermission();
                            if (Platform.isAndroid) {
                              bool serviceEnabled =
                                  await Geolocator.isLocationServiceEnabled();
                              print(
                                  "Is location service enabled $serviceEnabled");

                              if (serviceEnabled == true) {
                                BackgroundService().initializeService();
                              }
                            } else if (Platform.isIOS) {
                              getCurrentLocation();
                            }
                          } else {
                            if (Platform.isAndroid) {
                              BackgroundService().stopService();
                            }
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
            child: LinearProgressIndicator(
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
    print("Permission status $status");
    if (status.isGranted) {
      getCurrentLocation();
      // Location permission granted, proceed with location-related tasks.
    } else if (status.isDenied) {
      // Location permission denied. Show a message to the user.
    } else if (status.isPermanentlyDenied) {
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
      print("Connection status $isVisible");
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

class LocationWidget2 extends StatefulWidget {
  const LocationWidget2({Key? key}) : super(key: key);

  @override
  State<LocationWidget2> createState() => _LocationWidget2State();
}

class _LocationWidget2State extends State<LocationWidget2> {
  bool? serviceEnabled;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        body: SizedBox(
          height: size.height,
          width: size.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: size.height * 0.10,
              ),
              Icon(
                Icons.location_on_outlined,
                color: Colors.blue,
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                "Location Access",
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 22),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                "Allow to access this device location",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                    fontSize: 20),
              ),
              SizedBox(
                height: size.height * 0.15,
              ),
              Image.asset(
                "assets/images/location_access.jpg",
                scale: 3.3,
              ),
              SizedBox(
                height: size.height * 0.15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    height: 45,
                    width: 150,
                    child: ElevatedButton(
                        child: Text("No Thanks".toUpperCase(),
                            style: TextStyle(fontSize: 14)),
                        style: ButtonStyle(
                            foregroundColor:
                                MaterialStateProperty.all<Color>(Colors.white),
                            backgroundColor:
                                MaterialStateProperty.all<Color>(Colors.grey),
                            shape: MaterialStateProperty.all<
                                    RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey)))),
                        onPressed: () {
                          Navigator.pop(context);
                        }),
                  ),
                  SizedBox(
                    height: 45,
                    width: 150,
                    child: ElevatedButton(
                      child: Text("Trun On".toUpperCase(),
                          style: TextStyle(fontSize: 14)),
                      style: ButtonStyle(
                          foregroundColor:
                              MaterialStateProperty.all<Color>(Colors.white),
                          backgroundColor: MaterialStateProperty.all<Color>(
                              Color(0xff73BF2C)),
                          shape: MaterialStateProperty.all<
                                  RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Color(0xff73BF2C))))),
                      onPressed: _permissionStatus == PermissionStatus.granted
                          ? getCurrentLocation
                          : requestPermission,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Position? _currentPosition;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    checkPermissionStatus();
  }

  void checkPermissionStatus() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    setState(() {
      _permissionStatus = status;
    });
  }

  void requestPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.request();
    setState(() {
      _permissionStatus = status;
    });
    if (_permissionStatus == PermissionStatus.granted) {
      getCurrentLocation();
    }
  }

  void getCurrentLocation() async {
    if (_permissionStatus == PermissionStatus.granted) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } else {
      // Handle if permission is not granted
    }
  }
}
