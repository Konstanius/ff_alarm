import 'package:floor/floor.dart';

@entity
class Station  {
  @primaryKey
  final int id;

  String name;

  String area;

  String prefix;

  int stationNumber;

  String address;

  String coordinates;

  List<int>? units;

  List<int>? persons;

  List<int>? adminPersons;

  DateTime updated;

  int? priority;
  
  Station({
    required this.id,
    required this.name,
    required this.area,
    required this.prefix,
    required this.stationNumber,
    required this.address,
    required this.coordinates,
    required this.updated,
    this.units,
    this.persons,
    this.adminPersons,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "name": "n",
    "area": "a",
    "prefix": "p",
    "stationNumber": "s",
    "address": "ad",
    "coordinates": "c",
    "units": "u",
    "persons": "pe",
    "adminPersons": "ap",
    "updated": "up",
  };

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json[jsonShorts["id"]],
      name: json[jsonShorts["name"]],
      area: json[jsonShorts["area"]],
      prefix: json[jsonShorts["prefix"]],
      stationNumber: json[jsonShorts["stationNumber"]],
      address: json[jsonShorts["address"]],
      coordinates: json[jsonShorts["coordinates"]],
      units: List<int>.from(json[jsonShorts["units"]]),
      persons: List<int>.from(json[jsonShorts["persons"]]),
      adminPersons: List<int>.from(json[jsonShorts["adminPersons"]]),
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["name"]!: name,
      jsonShorts["area"]!: area,
      jsonShorts["prefix"]!: prefix,
      jsonShorts["stationNumber"]!: stationNumber,
      jsonShorts["address"]!: address,
      jsonShorts["coordinates"]!: coordinates,
      jsonShorts["units"]!: units,
      jsonShorts["persons"]!: persons,
      jsonShorts["adminPersons"]!: adminPersons,
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }
}
