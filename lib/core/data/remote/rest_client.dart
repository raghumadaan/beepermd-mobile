import 'dart:convert';

import 'package:flutter_udid/flutter_udid.dart';
import 'package:http/http.dart' as http;

// const BASE_URL_BACKEND = 'http://54.163.228.123/app/'; //STAG_1
// const BASE_URL_BACKEND = 'http://54.205.107.161/app/'; //STAG_2
const BASE_URL_BACKEND = 'https://beepermd.com/app/'; //PROD

// const BASE_URL_WEB = 'http://54.163.228.123/'; //STAG_1
// const BASE_URL_WEB = 'http://54.205.107.161/'; //STAG_2
const BASE_URL_WEB = 'https://beepermd.com/'; //PROD

class RestClient {
  Future<http.Response> post(apiName, sessionID, lat, long, docId) async {
    var headers = {
      "Cookie": "JSESSIONID=$sessionID",
      "Content-Type": "application/json"
    };
    String udid = await FlutterUdid.udid;
    var body = jsonEncode({
      "userId": docId,
      "latitude": lat,
      "longitude": long,
      "deviceId": udid
    });
    var url = Uri.parse(BASE_URL_BACKEND + apiName);
    final response =
        await http.Client().post(url, headers: headers, body: body);
    print("Here is the response ${response.body}");
    return response;
  }
}
