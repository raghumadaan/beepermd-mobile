import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class RestClient {
  var BaseURl = "http://54205.107.161/app/"; //"http://54.163.228.123/app/";
  Future<http.Response> post(apiName, sessionID, lat, long, docId) async {
    var headers = {
      "Cookie": "JSESSIONID=$sessionID",
      "Content-Type": "application/json"
    };
    var body =
        jsonEncode({"userId": docId, "latitude": lat, "longitude": long});

    var url = Uri.parse(BaseURl + apiName);
    final response =
        await http.Client().post(url, headers: headers, body: body);
    print(
        "THE RESPONSE OF POST ${response.statusCode} and TIME ${DateTime.now()} ");
    return response;
  }
}
