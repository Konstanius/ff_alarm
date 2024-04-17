import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/interfaces/station_interface.dart';
import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';

// Constant WebSocket listener to realtime updates on the server
class RealTimeListener {
  static Map<String, RealTimeListener> listeners = {};

  final String server;

  RealTimeListener(this.server);

  HttpClient client = HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  WebSocket? socket;
  int lastPing = 0;

  static Future<void> initAll() async {
    String registeredUsers = Globals.prefs.getString('registered_users') ?? '[]';
    List<String> users;
    try {
      users = jsonDecode(registeredUsers).cast<String>();
    } catch (e) {
      users = [];
    }

    for (String user in users) {
      String server = user.split(' ')[0];
      if (listeners.containsKey(server)) {
        await listeners[server]!.init();
        continue;
      }
      RealTimeListener listener = RealTimeListener(server);
      listeners[server] = listener;
      await listener.init();
    }
  }

  Future<void> reFetch() async {
    AlarmInterface.fetchAllForServerSilent(server);
    PersonInterface.fetchAllForServerSilent(server);
    StationInterface.fetchAllForServerSilent(server);
    UnitInterface.fetchAllForServerSilent(server);
  }

  static const List<int> pingBytes = [123, 34, 116, 34, 58, 34, 112, 105, 110, 103, 34, 125]; // {"t":"ping"}

  Future<void> init() async {
    if (!Globals.foreground) {
      try {
        await socket?.close();
        socket = null;
      } catch (_) {}
      return;
    } else if (socket != null && socket!.readyState == WebSocket.open) {
      if (DateTime.now().millisecondsSinceEpoch ~/ 1000 - lastPing > 10) {
        socket?.close();
        socket = null;
        init();

        Logger.warn('RealTimeListener: Socket closed due to inactivity');
        lastPing = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 5;

        reFetch();
      } else {
        socket?.addUtf8Text(pingBytes);
      }
      return;
    } else if (socket != null) {
      try {
        await socket!.close();
      } catch (_) {}

      reFetch();
    }

    try {
      socket = await WebSocket.connect('ws$server/realtime/', customClient: client, headers: Request.getAuthData(server));
    } catch (e, s) {
      Logger.warn('RealTimeListener: $e\n$s');
      return;
    }

    socket!.listen((event) async {
      try {
        String eventString;
        if (event is String) {
          eventString = event;
        } else {
          Logger.error('Realtime received invalid data: ${event.runtimeType}');
          return;
        }
        lastPing = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        Map<String, dynamic> packet = jsonDecode(eventString);
        if (packet.isEmpty) return;
        Logger.net('Realtime: $eventString');

        Map<String, dynamic> data = packet['data'];
        var method = packetTypes[packet['event']];
        if (method == null) {
          Logger.error('Realtime received invalid type: ${packet['event']}');
          return;
        }

        await method(data, server);
      } catch (e) {
        Logger.error('RealTimeListener: $e');
      }
    });

    lastPing = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}

Map<String, Future<void> Function(Map<String, dynamic> data, String server)> packetTypes = {
  "alarm": (Map<String, dynamic> data, String server) async {
    Alarm alarm = Alarm.fromJson(data);
    await Alarm.update(alarm, true);
  },
  "alarm_delete": (Map<String, dynamic> data, String server) async {
    int alarmId = data['id'];
    await Alarm.delete("$server $alarmId", true);
  },
  "person": (Map<String, dynamic> data, String server) async {
    Person person = Person.fromJson(data);
    await Person.update(person, true);
  },
  "person_delete": (Map<String, dynamic> data, String server) async {
    int personId = data['id'];
    await Person.delete("$server $personId", true);
  },
  "station": (Map<String, dynamic> data, String server) async {
    Station station = Station.fromJson(data);
    await Station.update(station, true);
  },
  "station_delete": (Map<String, dynamic> data, String server) async {
    int stationId = data['id'];
    await Station.delete("$server $stationId", true);
  },
  "unit": (Map<String, dynamic> data, String server) async {
    Unit unit = Unit.fromJson(data);
    await Unit.update(unit, true);
  },
  "unit_delete": (Map<String, dynamic> data, String server) async {
    int unitId = data['id'];
    await Unit.delete("$server $unitId", true);
  },
};
