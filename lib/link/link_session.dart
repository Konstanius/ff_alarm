import 'package:dio/dio.dart';

class LinkSession {
  static const String url = "https://pst.innomi.net";

  static String encodeForm(String content) {
    // lang=text&text=<content>&expire=-1&password=&title=
    String urlEncodedContent = Uri.encodeQueryComponent(content);
    return "lang=text&text=$urlEncodedContent&expire=-1&password=&title=";
  }

  static const Map<String, String> headers = {
    'accept-encoding': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'accept-language': 'en-GB,en,q=0.8',
    'cache-control': 'max-age=0',
    'connection': 'keep-alive',
    'content-type': 'application/x-www-form-urlencoded',
    'host': 'pst.innomi.net',
    'origin': 'https://pst.innomi.net',
    'referer': 'https://pst.innomi.net/',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'same-origin',
    'user-agent': 'FF Alarm App',
    'sec-ch-ua': '"FF_Alarm_App";v="1"',
    'cookie': '',
  };

  String identifier;
  String session;
  String authentication;

  LinkSession({required this.identifier, required this.session, required this.authentication});

  static Future<LinkSession> generateSession({required String content}) async {
    Response response = await Dio().post(
      "$url/paste/new",
      options: Options(
        followRedirects: false,
        contentType: 'application/x-www-form-urlencoded',
        preserveHeaderCase: true,
        responseType: ResponseType.plain,
        headers: headers,
        validateStatus: (status) => true,
      ),
      data: encodeForm(content),
    );
    if (response.statusCode == 303) {
      String location = response.headers['location']![0];
      List<String> cookies = response.headers['set-cookie']!;
      String? session;
      String? authentication;
      // iterate over cookies until both arent null, one starts with "session=" and the other with "authentication=", trim after first ;
      for (String cookie in cookies) {
        if (session == null && cookie.startsWith("session=")) {
          session = cookie.split(";")[0];
        } else if (authentication == null && cookie.startsWith("authentication=")) {
          authentication = cookie.split(";")[0];
        }
        if (session != null && authentication != null) {
          break;
        }
      }
      if (session != null && authentication != null) {
        String identifier = location.split("/").last;
        return LinkSession(identifier: identifier, session: session, authentication: authentication);
      } else {
        throw Exception("Session or authentication cookie not found");
      }
    } else {
      throw Exception("Failed to create session: ${response.statusCode}");
    }
  }

  Future<String> fetchContent() async {
    Response response = await Dio().get(
      "$url/paste/$identifier/raw",
      options: Options(
        followRedirects: false,
        contentType: 'application/x-www-form-urlencoded',
        preserveHeaderCase: true,
        responseType: ResponseType.plain,
        headers: headers,
        validateStatus: (status) => true,
      ),
    );
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception("Failed to fetch content: ${response.statusCode}");
    }
  }

  Future<void> updateContent({required String content}) async {
    Response response = await Dio().post(
      "$url/paste/$identifier/edit",
      options: Options(
        followRedirects: false,
        contentType: 'application/x-www-form-urlencoded',
        preserveHeaderCase: true,
        responseType: ResponseType.plain,
        headers: {
          ...headers,
          'cookie': "$session;$authentication",
        },
        validateStatus: (status) => true,
      ),
      data: encodeForm(content),
    );
    if (response.statusCode == 303) return;
    throw Exception("Failed to update content: ${response.statusCode}");
  }

  String exportData() {
    return "$identifier\n$session\n$authentication";
  }

  static LinkSession importData(String data) {
    List<String> parts = data.split("\n");
    if (parts.length == 3) {
      return LinkSession(identifier: parts[0], session: parts[1], authentication: parts[2]);
    } else {
      throw Exception("Invalid data");
    }
  }
}
