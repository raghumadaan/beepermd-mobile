import 'dart:convert';

import 'package:http/http.dart' as http;

// const BASE_URL = 'http://54.163.228.123/app/'; //STAG_1
// const BASE_URL = 'http://54.205.107.161/app/'; //STAG_2
const BASE_URL = 'https://beepermd.com/app/'; //PROD

class RestClient {
  Future<http.Response> post(apiName, sessionID, lat, long, docId) async {
    var headers = {
      "Cookie": "JSESSIONID=$sessionID",
      "Content-Type": "application/json"
    };
    print("Here the docId from user $docId");
    var body =
        jsonEncode({"userId": docId, "latitude": lat, "longitude": long});
    print("Here is the request body $body");
    var url = Uri.parse(BASE_URL + apiName);
    final response =
        await http.Client().post(url, headers: headers, body: body);
    print(
        "THE RESPONSE OF POST ${response.statusCode} and TIME ${DateTime.now()} ");
    return response;
  }
}
