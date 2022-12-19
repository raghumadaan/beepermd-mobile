import 'package:beepermd/main.dart';
import 'package:beepermd/screens/web_view_screen.dart';
import 'package:beepermd/services/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
   SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
 var url ='http://54.163.228.123/app/login/authm/';

 NavigateToWebView(){
   Future.delayed(Duration(milliseconds: 1500)).then((value) => Get.offAll(WebViewContainer(url)));
 }

 @override
  void initState() {
    super.initState();
    NavigateToWebView();
  }
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body:  Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage("assets/images/bg.png"))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              "assets/images/logo.png",
              height: size.height * 0.12,
            ),
            SizedBox(
              height: size.height * 0.02,
            ),
            Image.asset("assets/images/splash_logo.png"),
            SizedBox(
              height: size.height * 0.15,
            ),
            Center(
              child: GestureDetector(
                child: Container(
                  height: size.height * 0.07,
                  width: size.width * 0.65,
                  decoration: BoxDecoration(
                      color: Color(0xFF73BF2C),
                      borderRadius: BorderRadius.circular(25)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Get Started",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            ),textAlign: TextAlign.center,
                      ),
                      SizedBox(width: size.width*0.02,),
                      Icon(Icons.arrow_forward,color: Colors.white,size: 25,)
                    ],
                  ),
                ),
              ),

            ),
            SizedBox(height: size.height*0.015,),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Text(
                  "Need Any Help?",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    // fontWeight: FontWeight.bold,
                  ),textAlign: TextAlign.center,
                ),
                  Text(
                    "+1-866-550-2212",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),textAlign: TextAlign.center,
                  ),
              ],),
            )
          ],
        ),
      ),
    );
  }
}
