import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';

part 'alarm.g.dart';

@collection
class Alarm {
  @Name('id')
  final Id id;

  @Name('type')
  String type;

  @Name('word')
  String word;

  @Name('date')
  DateTime date;

  @Name('number')
  int number;

  @Name('address')
  String address;

  @Name('notes')
  List<String> notes;

  @Name('units')
  List<int> units;

  @Name('updated')
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
    };
  }

  factory Alarm.inflateFromString(String input) {
    final decodeBase64Json = base64.decode(input);
    final decodedZipJson = gzip.decode(decodeBase64Json);
    final originalJson = utf8.decode(decodedZipJson);
    final Map<String, dynamic> json = jsonDecode(originalJson);
    return Alarm.fromJson(json);
  }

  AlertOption getAlertOption() {
    DateTime now = DateTime.now();
    if (now.difference(date).inMinutes < 15 || date.difference(now).inMinutes < 15) {
      return AlertOption.alert;
    } else if (now.difference(date).inHours < 24 || date.difference(now).inHours < 24) {
      return AlertOption.silent;
    } else {
      return AlertOption.none;
    }
  }
}

enum AlertOption {
  alert,
  silent,
  none,
}
