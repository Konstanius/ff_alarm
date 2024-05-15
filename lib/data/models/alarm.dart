import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

@entity
class Alarm {
  @primaryKey
  final String id;
  String get server => id.split(' ')[0];
  int get idNumber => int.parse(id.split(' ')[1]);

  String type;

  String word;

  DateTime date;

  int number;

  String address;
  Position? get positionFromAddressIfCoordinates {
    var split = address.split(',');
    if (split.length != 2) return null;
    try {
      double? lat = double.tryParse(split[0]);
      double? lon = double.tryParse(split[1]);
      if (lat == null || lon == null) return null;
      return Position(
        latitude: lat,
        longitude: lon,
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        timestamp: DateTime.now(),
        floor: 0,
        isMocked: false,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> notes;

  List<int> units;
  List<String> get unitProperIds => units.map((e) => "$server $e").toList();

  Map<int, AlarmResponse> responses;
  AlarmResponse? get ownResponse {
    AlarmResponse? response;
    for (var entry in responses.entries) {
      String personId = "$server ${entry.key}";
      if (Globals.localPersons.containsKey(personId)) {
        response = entry.value;
        break;
      }
    }
    return response;
  }

  int updated;

  bool get responseTimeExpired => date.isBefore(DateTime.now().subtract(const Duration(hours: 1)));

  Alarm({
    required this.id,
    required this.type,
    required this.word,
    required this.date,
    required this.number,
    required this.address,
    required this.notes,
    required this.units,
    required this.responses,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "server": "s",
    "id": "i",
    "type": "t",
    "word": "w",
    "date": "d",
    "number": "n",
    "address": "a",
    "notes": "no",
    "units": "u",
    "responses": "r",
    "updated": "up",
  };

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: "${json[jsonShorts["server"]]} ${json[jsonShorts["id"]]}",
      type: json[jsonShorts["type"]],
      word: json[jsonShorts["word"]],
      date: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["date"]]),
      number: json[jsonShorts["number"]],
      address: json[jsonShorts["address"]],
      notes: List<String>.from(json[jsonShorts["notes"]]),
      units: List<int>.from(json[jsonShorts["units"]]),
      updated: json[jsonShorts["updated"]],
      responses: () {
        Map<int, AlarmResponse> result = {};
        Map<String, dynamic> decoded = json[jsonShorts["responses"]];
        decoded.forEach((key, value) {
          var response = AlarmResponse.fromJson(value);
          result[int.parse(key)] = response;
        });
        return result;
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["server"]!: server,
      jsonShorts["id"]!: idNumber,
      jsonShorts["type"]!: type,
      jsonShorts["word"]!: word,
      jsonShorts["date"]!: date.millisecondsSinceEpoch,
      jsonShorts["number"]!: number,
      jsonShorts["address"]!: address,
      jsonShorts["notes"]!: notes,
      jsonShorts["units"]!: units,
      jsonShorts["updated"]!: updated,
      jsonShorts["responses"]!: () {
        Map<String, dynamic> result = {};
        responses.forEach((key, value) {
          result[key.toString()] = value.toJson();
        });
        return result;
      }(),
    };
  }

  factory Alarm.inflateFromString(String input) {
    final decodeBase64Json = base64.decode(input);
    final decodedZipJson = gzip.decode(decodeBase64Json);
    final originalJson = utf8.decode(decodedZipJson);
    final Map<String, dynamic> json = jsonDecode(originalJson);
    return Alarm.fromJson(json);
  }

  Future<AlarmOption> getAlertOption(bool shouldNotify) async {
    DateTime now = DateTime.now();
    if (date.isAfter(now.subtract(const Duration(minutes: 15)))) {
      if (type.startsWith('Test')) {
        bool? muted = Globals.prefs.getBool('alarms_testsMuted');
        if (muted == true) return AlarmOption.silent;
      } else {
        bool? muted = Globals.prefs.getBool('alarms_muted');
        if (muted == true) return AlarmOption.silent;
      }

      return shouldNotify ? AlarmOption.alert : AlarmOption.silent;
    }

    if (date.isAfter(now.subtract(const Duration(hours: 24)))) return AlarmOption.silent;
    return AlarmOption.none;
  }

  static Future<List<Alarm>> getBatched({
    bool Function(Alarm)? filter,
    int? limit,
    String? startingId,
  }) async {
    var alarms = <Alarm>[];

    String lowestId = startingId ?? "\u{10FFFF}";
    const batchSize = 50;
    while (true) {
      var newAlarms = await Globals.db.alarmDao.getWithLowerIdThan(lowestId, batchSize);
      if (newAlarms.isEmpty) break;

      var toAdd = <Alarm>[];
      for (var alarm in newAlarms) {
        if (filter == null || filter(alarm)) toAdd.add(alarm);
        if (alarm.id.compareTo(lowestId) < 0) lowestId = alarm.id;

        if (limit != null && toAdd.length + alarms.length >= limit) break;
      }

      alarms.addAll(toAdd);
      if ((limit != null && alarms.length >= limit) || newAlarms.length < batchSize) break;
    }

    alarms.sort((a, b) => b.date.compareTo(a.date));

    return alarms;
  }

  static Future<List<Alarm>> getAll({bool Function(Alarm)? filter}) => getBatched(filter: filter);

  static Stream<List<Alarm>> getAllStreamed({int delay = 100}) async* {
    String lowestId = "\u{10FFFF}";
    const batchSize = 25;
    while (true) {
      var newAlarms = await Globals.db.alarmDao.getWithLowerIdThan(lowestId, batchSize);
      if (newAlarms.isEmpty) break;

      for (var alarm in newAlarms) {
        if (alarm.id.compareTo(lowestId) < 0) lowestId = alarm.id;
      }

      newAlarms.sort((a, b) => b.date.compareTo(a.date));
      yield newAlarms;
      if (newAlarms.length < batchSize) break;

      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  static Future<void> update(Alarm alarm, bool bc) async {
    // guarantee, that:
    // id contains a space
    // id split 0 != null
    // id split 1 != 0
    var splits = alarm.id.split(' ');
    if (splits.length != 2 || splits[0].isEmpty || splits[1].isEmpty) return;
    if (splits[0] == 'null' || splits[1] == '0') return;
    if (int.tryParse(splits[1]) == null) return;

    var existing = await Globals.db.alarmDao.getById(alarm.id);

    if (existing != null) {
      if (existing.updated >= alarm.updated) return;
      await Globals.db.alarmDao.updates(alarm);
    } else {
      await Globals.db.alarmDao.inserts(alarm);
    }

    if (!bc) return;
    UpdateInfo(UpdateType.alarm, {alarm.id});
  }

  static Future<void> delete(String alarmId, bool bc) async {
    await Globals.db.alarmDao.deleteById(alarmId);

    if (!bc) return;
    UpdateInfo(UpdateType.alarm, {alarmId});
  }

  static Future<int?> getAmount(String server) => Globals.db.alarmDao.getAmountWithServer(server);
}

enum AlarmOption {
  alert,
  silent,
  none,
}

/// Each responder gives a single response to each alarm
class AlarmResponse {
  /// The note left to be visible for other responders of the station they are not "Not going" to
  /// If the response is "Not going" to all stations, the note is visible to all responders
  String note;

  /// The time at which the response was given
  DateTime time;

  /// The type of response given, for each station
  Map<int, AlarmResponseType> responses;

  AlarmResponse({
    required this.note,
    required this.time,
    required this.responses,
  });

  static const Map<String, String> jsonShorts = {
    "note": "n",
    "time": "t",
    "responses": "r",
  };

  factory AlarmResponse.fromJson(Map<String, dynamic> json) {
    return AlarmResponse(
      note: json[jsonShorts["note"]],
      time: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["time"]]),
      responses: () {
        Map<int, AlarmResponseType> responses = {};
        json[jsonShorts["responses"]].forEach((key, value) {
          responses[int.parse(key)] = AlarmResponseType.values[value];
        });
        return responses;
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["note"]!: note,
      jsonShorts["time"]!: time.millisecondsSinceEpoch,
      jsonShorts["responses"]!: responses.map((key, value) => MapEntry(key.toString(), value.index)),
    };
  }

  ({int? stationId, AlarmResponseType responseType}) getResponseInfo() {
    int? stationId;
    AlarmResponseType? responseType;

    bool anyNotSet = false;
    for (var response in responses.entries) {
      if (response.value != AlarmResponseType.notReady && response.value != AlarmResponseType.notSet) {
        responseType = response.value;
        stationId = response.key;
        break;
      }

      if (response.value == AlarmResponseType.notSet) anyNotSet = true;
    }

    if (anyNotSet) responseType = AlarmResponseType.notSet;
    responseType ??= AlarmResponseType.notReady;

    return (stationId: stationId, responseType: responseType);
  }
}

enum AlarmResponseType {
  onStation(0),
  under5(5),
  under10(10),
  under15(15),
  onCall(-1),
  notReady(-2),
  notSet(-3);

  final int timeAmount;

  const AlarmResponseType(this.timeAmount);

  Color get color {
    switch (this) {
      case AlarmResponseType.onStation:
        return Colors.green;
      case AlarmResponseType.under5:
        return Colors.cyanAccent;
      case AlarmResponseType.under10:
        return Colors.yellow;
      case AlarmResponseType.under15:
        return Colors.orange;
      case AlarmResponseType.onCall:
        return Colors.purpleAccent;
      case AlarmResponseType.notReady:
        return Colors.red;
      case AlarmResponseType.notSet:
        return Colors.grey;
    }
  }

  String get name {
    switch (this) {
      case AlarmResponseType.onStation:
        return 'An Wache';
      case AlarmResponseType.under5:
        return '< 5 Min';
      case AlarmResponseType.under10:
        return '< 10 Min';
      case AlarmResponseType.under15:
        return '< 15 Min';
      case AlarmResponseType.onCall:
        return 'Auf Abruf dazu';
      case AlarmResponseType.notReady:
        return 'Nicht bereit';
      case AlarmResponseType.notSet:
        return 'Nicht gesetzt';
    }
  }
}
