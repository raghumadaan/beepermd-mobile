import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

class HTMLParserService {
  Future<void> parserMethod() async {
    try{
      final response = await http.Client().get(
          Uri.parse('http://54.163.228.123/app/schedule'));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        print("The PARSER  ${document.getElementsByTagName("link")}");
        print("THE DOCUMENT  ${document.outerHtml}");
      }else {
        throw Exception();
      }
    }catch(e){
      print("THE ERROR IS $e");
    }

    }

  }
