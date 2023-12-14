import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beepermd/core/data/remote/rest_client.dart';
import 'package:beepermd/services/background_services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fetchBackground = "fetchBackground";

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
  String fileFormat = "";
  bool isApiLoaded = true;
  var userIdForMobileApp;
  String? patientCookie = '';
  String? providerCookie = '';
  String? loggedInUserId = '';

  DateTime? backButtonPressTime;
  final CookieManager _cookieManager = CookieManager.instance();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String? actualFilePath;
  static const snackBarDuration = Duration(seconds: 3);
  var initialUrl = '${BASE_URL_WEB}patient';

  final snackBar = const SnackBar(
    content: Text('Press back again to leave'),
    duration: snackBarDuration,
  );

  getCookiesAndSaveInPref(String sessionId, String userType) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(userType, sessionId);
  }

  saveUserIDinPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
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

  bool isFirst = true;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    if (providerCookie!.isNotEmpty) {
      initialUrl = '${BASE_URL_WEB}app/schedule';
    } else if (patientCookie!.isNotEmpty) {
      initialUrl = '${BASE_URL_WEB}patient/#/home';
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
                            useOnDownloadStart: true,
                            disableDefaultErrorPage: true),
                        pullToRefreshController: pullToRefreshController,
                        initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
                        onWebViewCreated: (InAppWebViewController controller) {
                          _webViewController = controller;
                        },
                        onLoadStart: (controller, url) async {
                          if (url?.rawValue ==
                              "${BASE_URL_BACKEND}login/authm") {
                            final SharedPreferences prefs = await _prefs;
                            prefs.clear();
                            BackgroundService().stopService();
                          }
                        },
                        onLoadStop: (controller, url) async {
                          final SharedPreferences prefs = await _prefs;
                          controller.addJavaScriptHandler(
                              handlerName: "blobToBase64Handler",
                              callback: (args) async {
                                var bytes = base64Decode(args[0]);
                                await callFolderCreationMethod();
                                DateTime now = DateTime.now();
                                String fileName =
                                    "Test Report-${now.microsecondsSinceEpoch}.$fileFormat";
                                final file = File("$actualFilePath/$fileName");
                                await file
                                    .writeAsBytes(bytes.buffer.asUint8List());
                                Navigator.of(context).pop();
                                Fluttertoast.showToast(
                                    msg:
                                        'Test result downloaded, please check your downloads folder.',
                                    webPosition: "right",
                                    webShowClose: true,
                                    toastLength: Toast.LENGTH_LONG,
                                    gravity: ToastGravity.TOP,
                                    backgroundColor: Colors.green,
                                    textColor: Colors.white,
                                    fontSize: 16.0);
                                return args.reduce((curr, next) => curr + next);
                              });
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

                          if (url?.rawValue == "${BASE_URL_WEB}app/schedule") {
                            prefs.remove("patient");
                            patientCookie = '';
                            String sessionId = await getCookie(url, "provider");
                            var header = {"Cookie": "JSESSIONID=$sessionId"};
                            var status =
                                await Permission.locationWhenInUse.status;
                            if (isFirst) {
                              setState(() {
                                isFirst = false;
                              });
                              if (status != PermissionStatus.granted) {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LocationWidget2()));
                              } else {}
                            }
                            final response = await http.Client()
                                .get(Uri.parse(url!.rawValue), headers: header);
                            dom.Document document =
                                htmlparser.parse(response.body);
                            var data =
                                document.getElementById('userIdForMobileApp');
                            document.getElementById('userIdForMobileApp');

                            if (data?.attributes
                                    .containsValue('userIdForMobileApp') ??
                                false) {
                              userIdForMobileApp = data!.nodes[0];
                              print(
                                  "here is the userId ${userIdForMobileApp.data}");
                              saveUserIDinPrefs(userIdForMobileApp.data);
                            }
                            bool serviceEnabled =
                                await Geolocator.isLocationServiceEnabled();
                            print(
                                "Is location service enabled $serviceEnabled");
                            if (serviceEnabled == true &&
                                status == PermissionStatus.granted) {
                              BackgroundService().initializeService();
                            }
                          } else if (url?.rawValue ==
                              "${BASE_URL_WEB}patient/#/home") {
                            prefs.remove("provider");
                            providerCookie = '';
                            String sessionId = await getCookie(url, "patient");
                            print("debugger in else if condition $sessionId");
                            await _handleStoragePermission();
                          }
                        },
                        onDownloadStartRequest: (controller, url) async {
                          buildShowDialog(context);
                          print("onDownloadStart ${url.url.path}");

                          String urlLink = url.contentDisposition!;
                          if (urlLink != "") {
                            if (urlLink.contains("pdf")) {
                              fileFormat = "pdf";
                            } else if (urlLink.contains("jpg")) {
                              fileFormat = "jpg";
                            } else if (urlLink.contains("jpeg")) {
                              fileFormat = "jpeg";
                            } else if (urlLink.contains("png")) {
                              fileFormat = "png";
                            }
                          } else if (url.suggestedFilename != null) {
                            if (url.suggestedFilename!.contains("pdf")) {
                              fileFormat = "pdf";
                            }
                          }

                          var jsContent = await rootBundle
                              .loadString("assets/js/base64.js");
                          var result = await controller.evaluateJavascript(
                              source: jsContent.replaceAll(
                                  "blobUrlPlaceholder", url.url.toString()));
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

  Future<String> createFolderInAppDocDir() async {
    //Get this App Document Directory

    final Directory _appDocDirFolder =
        Directory('/storage/emulated/0/Download');

    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return _appDocDirFolder.path;
    } else {
      //if folder not exists create folder and then return its path
      final Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);
      return _appDocDirNewFolder.path;
    }
  }

  callFolderCreationMethod() async {
    actualFilePath = await createFolderInAppDocDir();
    print("path $actualFilePath");
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
      print('Couldn\'t check connectivity status $e');
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

  Future<bool> _handleStoragePermission() async {
    // bool serviceEnabled;
    PermissionStatus result;
    if (Platform.isAndroid) {
      result = (await Permission.storage.request());
      if (result.isGranted) {
        // Either the permission was already granted before or the user just granted it.
        print("Storage Permission is granted");
        return true;
      } else {
        print("Storage Permission is denied.");
        return false;
      }
    }
    return false;
  }

  buildShowDialog(BuildContext context) {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
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
              const Icon(
                Icons.location_on_outlined,
                color: Colors.blue,
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                "Use your location",
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 22),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                "BeeperMD App collects location data to share provider's real time location updates with patients",
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
                          _handleCameraPermission();
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
                                const Color(0xff73BF2C)),
                            shape: MaterialStateProperty.all<
                                    RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(
                                        color: Color(0xff73BF2C))))),
                        onPressed: () {
                          // _permissionStatus == PermissionStatus.granted
                          //     ? getCurrentLocation
                          // :
                          requestPermission(context);
                        }),
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
    // checkPermissionStatus();
  }

  void checkPermissionStatus() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    setState(() {
      _permissionStatus = status;
    });
  }

  void requestPermission(context) async {
    PermissionStatus status = await Permission.locationWhenInUse.request();
    setState(() {
      _permissionStatus = status;
    });
    if (_permissionStatus == PermissionStatus.granted) {
      getCurrentLocation();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print("Is location service enabled $serviceEnabled");

      if (serviceEnabled == true) {
        BackgroundService().initializeService();
        await _handleCameraPermission();
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _handleCameraPermission() async {
    // bool serviceEnabled;
    PermissionStatus result;
    if (Platform.isAndroid) {
      result = (await Permission.camera.request());
      if (result.isGranted) {
        // Either the permission was already granted before or the user just granted it.
        print("Location Permission is granted");
        return true;
      } else {
        print("Location Permission is denied.");
        return false;
      }
    }
    return false;
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

  Future<bool> _handleLocationPermission(BuildContext context) async {
    // bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled!) {
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
}
