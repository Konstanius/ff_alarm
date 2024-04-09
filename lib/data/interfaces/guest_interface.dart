import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/server/request.dart';

abstract class GuestInterface {
  static Future<({String token, int sessionId, Person person})> login({required int personId, required String key, required String server}) async {
    String userAgent = '';

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      userAgent = 'Android ${androidInfo.version.release} - ${androidInfo.model}, ${androidInfo.device}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await DeviceInfoPlugin().iosInfo;
      userAgent = 'iOS ${iosInfo.systemVersion} - ${iosInfo.utsname.machine}, ${iosInfo.name}';
    } else {
      userAgent = 'Unknown ${Platform.operatingSystem}';
    }

    Map<String, dynamic> data = {
      "person": personId,
      "key": key,
      "userAgent": userAgent,
    };

    Request response = await Request('login', data, server).emit(true, guest: true);

    String token = response.ackData!['token'];
    int sessionId = response.ackData!['sessionId'];
    Person person = Person.fromJson(response.ackData!['person']);

    return (token: token, sessionId: sessionId, person: person);
  }
}
