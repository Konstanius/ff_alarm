import 'package:isar/isar.dart';

part 'station.g.dart';

@collection
class Station  {
  @Name('id')
  final Id id;

  @Name('name')
  String name;

  @Name('area')
  String area;
  
  @Name('prefix')
  String prefix;
  
  @Name('stationNumber')
  int stationNumber;
  
  @Name('address')
  String address;
  
  @Name('coordinates')
  String coordinates;

  @Name('units')
  List<int>? units;
  
  @Name('persons')
  List<int>? persons;
  
  @Name('adminPersons')
  List<int>? adminPersons;

  @Name('updated')
  DateTime updated;

  @Name('priority')
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
