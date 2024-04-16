import 'dart:convert';

import 'package:flutter_udid/flutter_udid.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/failed_request.dart';
import 'failed_request_manager.dart';

// const BASE_URL_BACKEND = 'http://54.163.228.123/app/'; //STAG_1
// const BASE_URL_BACKEND = 'http://54.205.107.161/app/'; //STAG_2
const BASE_URL_BACKEND = 'https://beepermd.com/app/'; //PROD

// const BASE_URL_WEB = 'http://54.163.228.123/'; //STAG_1
// const BASE_URL_WEB = 'http://54.205.107.161/'; //STAG_2
const BASE_URL_WEB = 'https://beepermd.com/'; //PROD

class RestClient {
  Future<http.Response> postFCMToken(Map body) async {
    var headers = {"Content-Type": "application/json"};
    try {
      var url = Uri.parse('${BASE_URL_BACKEND}user/registerDevice');
      final response =
          await http.Client().post(url, headers: headers, body: body);
      print("Here is the response ${response.body}");
      return response;
    } catch (e) {
      // handle error
      print("Error during post request: $e");
      throw e; // Re-throw the error for further handling
    }
  }

  Future<http.Response> post(apiName, sessionID, lat, long, docId) async {
    var headers = {
      "Cookie": "JSESSIONID=$sessionID",
      "Content-Type": "application/json"
    };
    String udid = await FlutterUdid.udid;

    try {
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
    } catch (e) {
      // handle error
      final failedRequest = FailedRequest(
        apiName: apiName,
        sessionID: sessionID,
        lat: lat,
        long: long,
        deviceId: docId,
        timestamp: DateTime.now(),
      );
      // Save failed request to local storage
      await FailedRequestManager().saveRequest(failedRequest);
      print("Error during post request: $e");
      throw e; // Re-throw the error for further handling
    }
  }
}
