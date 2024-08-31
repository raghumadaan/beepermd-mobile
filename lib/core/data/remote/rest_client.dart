import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart' as dioClient;
import 'package:flutter/material.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:http/http.dart' as http;

import '../../model/failed_request.dart';
import 'failed_request_manager.dart';

// const BASE_URL_BACKEND = 'http://54.163.228.123/app/'; //STAG_1
// const BASE_URL_BACKEND = 'http://54.205.107.161/app/'; //STAG_2
// const BASE_URL_BACKEND = 'https://uat.beepermd.com/app/'; //UAT
const BASE_URL_BACKEND = 'https://beepermd.com/app/'; //PROD

// const BASE_URL_WEB = 'http://54.163.228.123/'; //STAG_1
// const BASE_URL_WEB = 'http://54.205.107.161/'; //STAG_2
// const BASE_URL_WEB = 'https://uat.beepermd.com/'; //UAT
const BASE_URL_WEB = 'https://beepermd.com/'; //PROD

class RestClient {
  Future<dioClient.Response<dynamic>> getWithDioRedirects(
      String url, Map<String, dynamic>? headers) async {
    final dio = dioClient.Dio(
      dioClient.BaseOptions(
        headers: headers,
        followRedirects: false, // Disable automatic redirects
        maxRedirects: 10, // Set a maximum redirect limit
      ),
    );

    try {
      dioClient.Response<dynamic> response;
      do {
        response = await dio.get(url);

        if (response.statusCode! >= 300 && response.statusCode! < 400) {
          // Extract new URL from Location header
          log('Redirecting to: ${response.headers['location']}');
          final newUrl =
              response.data['location'] ?? response.headers['location'];
          if (newUrl != null) {
            url = newUrl;
          } else {
            // Handle missing location header error
            throw dioClient.DioError(
              requestOptions: response.requestOptions,
              type: dioClient.DioErrorType.badResponse,
              error: 'Missing location header in redirect response',
            );
          }
        }
      } while (response.statusCode! >= 300 && response.statusCode! < 400);

      return response;
    } on dioClient.DioError catch (e) {
      // Handle other Dio errors (e.g., network errors, timeouts)
      if (e.type == dioClient.DioErrorType.badResponse) {
        // Handle non-2xx status codes (e.g., 404, 500)
        throw Exception('Error fetching data: ${e.response?.statusCode}');
      } else {
        // Handle other Dio error types (e.g., network errors, timeouts)
        throw Exception('Error during request: ${e.message}');
      }
    }
  }

  Future<http.Response> postFCMToken(
      String userId, String deviceId, String fcmToken, String sessionID) async {
    var headers = {
      "Content-Type": "application/json",
      "Cookie": "JSESSIONID=$sessionID",
    };

    try {
      var body = {
        "userId": userId,
        "deviceId": deviceId,
        "fcmToken": fcmToken,
        "deviceType": Platform.operatingSystem,
      };
      var url = Uri.parse('${BASE_URL_BACKEND}user/registerDevice');

      final response =
          await http.post(url, body: jsonEncode(body), headers: headers);

      debugPrint("Here is the response ${response.body}");
      return response;
    } catch (e) {
      // handle error
      debugPrint("Error during post request: $e");
      rethrow; // Re-throw the error for further handling
    }
  }

  Future<http.Response?> post(apiName, sessionID, lat, long, docId,
      [timestamp]) async {
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
        "deviceId": udid,
        if (timestamp != null) "timestamp": timestamp.toIso8601String(),
      });
      var url = Uri.parse(BASE_URL_BACKEND + apiName);
      final response =
          await http.Client().post(url, headers: headers, body: body);
      debugPrint("Here is the response ${response.body}");
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
      debugPrint("Error during post request: $e");
      return null;
    }
  }
}
