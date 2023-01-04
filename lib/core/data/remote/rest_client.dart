import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RestClient{

  var BaseURl = "http://54.163.228.123/app/";


  Future<http.Response> post(apiName,sessionID,lat,long,docId)async{
    var headers = {
    "Cookie":"JSESSIONID=$sessionID",
    "Content-Type":"application/json"
    };
    var body=jsonEncode({
      "userId": docId,
      "latitude": lat,
      "longitude": long
    });

    var url = Uri.parse(BaseURl+apiName);
    final response = await http.Client().post(url,headers: headers,body: body);
    var jsonResponse = jsonDecode(response.body);
    print("the json response $jsonResponse");
    Fluttertoast.showToast(
        msg: "${jsonResponse["message"]}",
        webPosition: "right",
        webShowClose: true,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        timeInSecForIosWeb: 1,
        backgroundColor:response.statusCode ==200? Colors.green:Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
    );
    print("THE RESPONSE OF POST ${response.body}" );
    return response;
  }
}