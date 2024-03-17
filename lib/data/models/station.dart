import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
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

  List<int> units;

  List<int> persons;

  List<int> adminPersons;

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
    required this.units,
    required this.persons,
    required this.adminPersons,
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

  static Future<List<Station>> getBatched({
    bool Function(Station)? filter,
    int? limit,
    int startingId = 2 ^ 31,
  }) async {
    var stations = <Station>[];

    int lowestId = startingId;
    const batchSize = 50;
    while (true) {
      var newStations = await Globals.db.stationDao.getWithLowerIdThan(startingId, batchSize);
      if (newStations.isEmpty) break;

      var toAdd = <Station>[];
      for (var station in newStations) {
        if (filter == null || filter(station)) toAdd.add(station);
        if (station.id < lowestId) lowestId = station.id;

        if (limit != null && toAdd.length + stations.length >= limit) break;
      }

      stations.addAll(toAdd);
      if ((limit != null && stations.length >= limit) || newStations.length < batchSize) break;
    }

    stations.sort((a, b) => a.name.compareTo(b.name));

    return stations;
  }

  static Future<List<Station>> getAll({bool Function(Station)? filter}) => getBatched(filter: filter);

  static Future<void> update(Station station, bool bc) async {
    var existing = await Globals.db.stationDao.getById(station.id);
    if (existing != null) {
      if (existing.updated.isAfter(station.updated)) return;
      await Globals.db.stationDao.updates(station);
    } else {
      await Globals.db.stationDao.inserts(station);
    }

    if (!bc) return;
    UpdateInfo(UpdateType.station, {station.id});
  }

  static Future<void> delete(int stationId, bool bc) async {
    await Globals.db.stationDao.deleteById(stationId);

    if (!bc) return;
    UpdateInfo(UpdateType.station, {stationId});
  }
}
