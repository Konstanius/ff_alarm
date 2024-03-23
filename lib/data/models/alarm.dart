import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';

import '../../ui/popups/alarm_info.dart';

@entity
class Alarm {
  @primaryKey
  final int id;

  String type;

  String word;

  DateTime date;

  int number;

  String address;

  List<String> notes;

  List<int> units;

  Map<int, AlarmResponse> responses;

  int updated;

  bool get responseTimeExpired => date.isBefore(DateTime.now().subtract(const Duration(minutes: 20)));

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
      id: json[jsonShorts["id"]],
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
          if (response != null) result[int.parse(key)] = response;
        });
        return result;
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
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

  AlarmOption getAlertOption() {
    DateTime now = DateTime.now();
    if (date.isAfter(now.subtract(const Duration(minutes: 15)))) {
      if (type.startsWith('Test')) {
        bool? muted = Globals.prefs.getBool('alarms_testsMuted');
        if (muted == true) return AlarmOption.silent;
      } else {
        bool? muted = Globals.prefs.getBool('alarms_muted');
        if (muted == true) return AlarmOption.silent;
      }
      return AlarmOption.alert;
    }
    if (date.isAfter(now.subtract(const Duration(hours: 24)))) return AlarmOption.silent;
    return AlarmOption.none;
  }

  static Future<List<Alarm>> getBatched({
    bool Function(Alarm)? filter,
    int? limit,
    int? startingId,
  }) async {
    var alarms = <Alarm>[];

    int lowestId = startingId ?? double.maxFinite.toInt();
    const batchSize = 50;
    while (true) {
      var newAlarms = await Globals.db.alarmDao.getWithLowerIdThan(lowestId, batchSize);
      if (newAlarms.isEmpty) break;

      var toAdd = <Alarm>[];
      for (var alarm in newAlarms) {
        if (filter == null || filter(alarm)) toAdd.add(alarm);
        if (alarm.id < lowestId) lowestId = alarm.id;

        if (limit != null && toAdd.length + alarms.length >= limit) break;
      }

      alarms.addAll(toAdd);
      if ((limit != null && alarms.length >= limit) || newAlarms.length < batchSize) break;
    }

    alarms.sort((a, b) => b.date.compareTo(a.date));

    return alarms;
  }

  static Future<List<Alarm>> getAll({bool Function(Alarm)? filter}) => getBatched(filter: filter);

  static Future<void> update(Alarm alarm, bool bc) async {
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

  static Future<void> delete(int alarmId, bool bc) async {
    await Globals.db.alarmDao.deleteById(alarmId);

    if (!bc) return;
    UpdateInfo(UpdateType.alarm, {alarmId});
  }
}

enum AlarmOption {
  alert,
  silent,
  none,
}

class AlarmResponse {
  String? note;
  DateTime? time;
  AlarmResponseType type;
  int? stationId;

  AlarmResponse({this.note, this.time, required this.type, this.stationId});

  static AlarmResponse? fromJson(Map<String, dynamic>? json) {
    if (json == null || !json.containsKey('d')) return null;
    return AlarmResponse(
      note: json['n'],
      time: json['t'] != null ? DateTime.fromMillisecondsSinceEpoch(json['t']) : null,
      type: AlarmResponseType.values[json['d']],
      stationId: json['s'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': note,
      't': time?.millisecondsSinceEpoch,
      'd': type.index,
      's': stationId,
    };
  }
}
