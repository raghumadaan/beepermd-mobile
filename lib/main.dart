import 'package:beepermd/screens/web_view_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import 'core/data/remote/failed_request_manager.dart';
import 'firebase_options.dart';
import 'services/firebase_notification_service.dart';

const fetchBackground = "fetchBackground";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  await Firebase.initializeApp(
      name: 'beepermd', options: DefaultFirebaseOptions.currentPlatform);

  await Future.delayed(const Duration(seconds: 1));

  FirebaseNotificationService.init();

  await FailedRequestManager().initialize();

  runApp(const GetMaterialApp(
    home: WebViewContainer(),
    debugShowCheckedModeBanner: false,
  ));
}
