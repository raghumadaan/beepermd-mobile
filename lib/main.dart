import 'package:beepermd/screens/web_view_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'core/data/remote/failed_request_manager.dart';
import 'services/firebase_notification_service.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

const fetchBackground = "fetchBackground";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FailedRequestManager().initialize();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseNotificationService.init();

  runApp(const MaterialApp(
    home: WebViewContainer(),
    debugShowCheckedModeBanner: false,
  ));
}
