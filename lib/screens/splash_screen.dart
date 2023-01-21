// import 'package:beepermd/screens/web_view_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({Key? key}) : super(key: key);
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   var url = 'http://54.163.228.123/app/login/authm/';
//   var svg = "assets/svg/splash_screen_final.svg";
//
//   navigateToWebView() {
//     Future.delayed(const Duration(milliseconds: 1500))
//         .then((value) => Get.offAll(WebViewContainer(url)));
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     navigateToWebView();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//     return Scaffold(
//       body: Container(
//         height: size.height,
//         width: size.width,
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage("assets/images/splash_logo_final.jpg"),
//             fit: BoxFit.cover
//           ),
//         ),
//
//       ),
//     );
//   }
// }
