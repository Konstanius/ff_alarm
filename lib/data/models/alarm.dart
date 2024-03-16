import 'dart:convert';
import 'dart:io';

import 'package:floor/floor.dart';

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

  DateTime updated;

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
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
      responses: () {
        Map<int, AlarmResponse> result = {};
        Map<String, dynamic> decoded = json[jsonShorts["responses"]];
        decoded.forEach((key, value) {
          result[int.parse(key)] = AlarmResponse.fromJson(value);
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
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
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
    if (now.difference(date).inMinutes < 15 || date.difference(now).inMinutes < 15) {
      return AlarmOption.alert;
    } else if (now.difference(date).inHours < 24 || date.difference(now).inHours < 24) {
      return AlarmOption.silent;
    } else {
      return AlarmOption.none;
    }
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
  int? duration;

  AlarmResponse({this.note, this.time, this.duration});

  factory AlarmResponse.fromJson(Map<String, dynamic> json) {
    return AlarmResponse(
      note: json['n'],
      time: json['t'] != null ? DateTime.fromMillisecondsSinceEpoch(json['t']) : null,
      duration: json['d'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': note,
      't': time?.millisecondsSinceEpoch,
      'd': duration,
    };
  }
}
