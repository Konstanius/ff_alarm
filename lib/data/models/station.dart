import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';
import 'package:geolocator/geolocator.dart';

@entity
class Station {
  @primaryKey
  final String id;
  String get server => id.split(' ')[0];
  int get idNumber => int.parse(id.split(' ')[1]);

  String name;

  String area;

  String prefix;

  int stationNumber;

  String address;

  String coordinates;
  Position? get position {
    var split = coordinates.split(',');
    try {
      return Position(
        latitude: double.parse(split[0]),
        longitude: double.parse(split[1]),
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

  List<int> persons;
  List<String> get personProperIds => persons.map((e) => "$server $e").toList();

  List<int> adminPersons;
  List<String> get adminPersonProperIds => adminPersons.map((e) => "$server $e").toList();

  int updated;

  Station({
    required this.id,
    required this.name,
    required this.area,
    required this.prefix,
    required this.stationNumber,
    required this.address,
    required this.coordinates,
    required this.updated,
    required this.persons,
    required this.adminPersons,
  });

  static const Map<String, String> jsonShorts = {
    "server": "s",
    "id": "i",
    "name": "n",
    "area": "a",
    "prefix": "p",
    "stationNumber": "sn",
    "address": "ad",
    "coordinates": "c",
    "persons": "pe",
    "adminPersons": "ap",
    "updated": "up",
  };

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: "${json[jsonShorts["server"]]} ${json[jsonShorts["id"]]}",
      name: json[jsonShorts["name"]],
      area: json[jsonShorts["area"]],
      prefix: json[jsonShorts["prefix"]],
      stationNumber: json[jsonShorts["stationNumber"]],
      address: json[jsonShorts["address"]],
      coordinates: json[jsonShorts["coordinates"]],
      persons: List<int>.from(json[jsonShorts["persons"]]),
      adminPersons: List<int>.from(json[jsonShorts["adminPersons"]]),
      updated: json[jsonShorts["updated"]],
    );
  }

  static Future<List<Station>> getBatched({
    bool Function(Station)? filter,
    int? limit,
    String? startingId,
  }) async {
    var stations = <Station>[];

    String lowestId = startingId ?? "\u{10FFFF}";
    const batchSize = 50;
    while (true) {
      var newStations = await Globals.db.stationDao.getWithLowerIdThan(lowestId, batchSize);
      if (newStations.isEmpty) break;

      var toAdd = <Station>[];
      for (var station in newStations) {
        if (filter == null || filter(station)) toAdd.add(station);
        if (station.id.compareTo(lowestId) < 0) lowestId = station.id;

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
    // guarantee, that:
    // id contains a space
    // id split 0 != null
    // id split 1 != 0
    var splits = station.id.split(' ');
    if (splits.length != 2 || splits[0].isEmpty || splits[1].isEmpty) return;
    if (splits[0] == 'null' || splits[1] == '0') return;
    if (int.tryParse(splits[1]) == null) return;

    var existing = await Globals.db.stationDao.getById(station.id);
    if (existing != null) {
      if (existing.updated >= station.updated) return;
      await Globals.db.stationDao.updates(station);
    } else {
      await Globals.db.stationDao.inserts(station);
    }

    if (!bc) return;
    UpdateInfo(UpdateType.station, {station.id});
  }

  static Future<void> delete(String stationId, bool bc) async {
    await Globals.db.stationDao.deleteById(stationId);

    if (!bc) return;
    UpdateInfo(UpdateType.station, {stationId});
  }

  static Future<int?> getAmount(String server) => Globals.db.stationDao.getAmountWithPrefix(server);
}
