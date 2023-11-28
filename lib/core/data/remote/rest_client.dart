import 'dart:convert';

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
    var body =
        jsonEncode({"userId": docId, "latitude": lat, "longitude": long});
    var url = Uri.parse(BASE_URL_BACKEND + apiName);
    final response =
        await http.Client().post(url, headers: headers, body: body);
    print(
        "THE RESPONSE OF POST ${response.statusCode} and TIME ${DateTime.now()} ");
    return response;
  }
}
