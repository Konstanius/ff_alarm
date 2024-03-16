import 'package:ff_alarm/data/models/alarm.dart';
import 'package:floor/floor.dart';

@entity
class Person {
  @primaryKey
  final int id;

  String firstName;

  String lastName;

  List<int> allowedUnits;

  /// Qualifications Format:
  /// comma separated, no spaces
  /// Supported:
  /// - tm (Truppmann)
  /// - tf (Truppführer)
  /// - agt (Atemschutzgeräteträger)
  /// - gf (Gruppenführer)
  /// - zf (Zugführer)
  /// - ma (Maschinist)
  /// - b (B-Führerschen)
  /// - c1 (C-Führerschein)
  /// - c (C-Führerschein)
  /// - ce (CE-Führerschein)
  /// - bo (Bootsführerschein)
  String qualifications;

  AlarmResponse response;

  DateTime updated;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.allowedUnits,
    required this.qualifications,
    required this.response,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "firstName": "f",
    "lastName": "l",
    "allowedUnits": "au",
    "qualifications": "q",
    "response": "r",
    "updated": "up",
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json[jsonShorts["id"]],
      firstName: json[jsonShorts["firstName"]],
      lastName: json[jsonShorts["lastName"]],
      allowedUnits: List<int>.from(json[jsonShorts["allowedUnits"]]),
      qualifications: json[jsonShorts["qualifications"]],
      response: AlarmResponse.fromJson(json[jsonShorts["response"]]),
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["firstName"]!: firstName,
      jsonShorts["lastName"]!: lastName,
      jsonShorts["allowedUnits"]!: allowedUnits,
      jsonShorts["qualifications"]!: qualifications,
      jsonShorts["response"]!: response.toJson(),
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }
}
