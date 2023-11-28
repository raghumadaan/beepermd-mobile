import 'dart:convert';

import 'package:http/http.dart' as http;

// const BASE_URL = 'http://54.163.228.123/'; //STAG_1
// const BASE_URL = 'http://54.205.107.161/'; //STAG_2
const BASE_URL = 'https://beepermd.com/'; //PROD

class RestClient {
  Future<http.Response> post(apiName, sessionID, lat, long, docId) async {
    var headers = {
      "Cookie": "JSESSIONID=$sessionID",
      "Content-Type": "application/json"
    };
    var body =
        jsonEncode({"userId": docId, "latitude": lat, "longitude": long});
    var url = Uri.parse(BASE_URL + apiName);
    final response =
        await http.Client().post(url, headers: headers, body: body);
    return response;
  }
}
