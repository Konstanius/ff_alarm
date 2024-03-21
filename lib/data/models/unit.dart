import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';

@entity
class Unit {
  @primaryKey
  final int id;

  int stationId;

  int unitType;

  int unitIdentifier;

  String unitDescription;

  int status;

  List<UnitPosition> positions;

  int capacity;

  int updated;

  Unit({
    required this.id,
    required this.stationId,
    required this.unitType,
    required this.unitIdentifier,
    required this.unitDescription,
    required this.status,
    required this.positions,
    required this.capacity,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "stationId": "si",
    "unitType": "ut",
    "unitIdentifier": "ui",
    "unitDescription": "ud",
    "status": "st",
    "positions": "po",
    "capacity": "ca",
    "updated": "up",
  };

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json[jsonShorts["id"]],
      stationId: json[jsonShorts["stationId"]],
      unitType: json[jsonShorts["unitType"]],
      unitIdentifier: json[jsonShorts["unitIdentifier"]],
      unitDescription: json[jsonShorts["unitDescription"]],
      status: json[jsonShorts["status"]],
      positions: List<UnitPosition>.from(json[jsonShorts["positions"]].map((e) => UnitPosition.values[e])),
      capacity: json[jsonShorts["capacity"]],
      updated: json[jsonShorts["updated"]],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["stationId"]!: stationId,
      jsonShorts["unitType"]!: unitType,
      jsonShorts["unitIdentifier"]!: unitIdentifier,
      jsonShorts["unitDescription"]!: unitDescription,
      jsonShorts["status"]!: status,
      jsonShorts["positions"]!: positions.map((e) => e.index).toList(),
      jsonShorts["capacity"]!: capacity,
      jsonShorts["updated"]!: updated,
    };
  }

  String unitCallSign(Station station) {
    return "${station.prefix} ${station.area} ${station.stationNumber}-$unitType-$unitIdentifier";
  }

  static Future<List<Unit>> getBatched({
    bool Function(Unit)? filter,
    int? limit,
    int? startingId,
  }) async {
    var units = <Unit>[];

    int lowestId = startingId ?? double.maxFinite.toInt();
    const batchSize = 50;
    while (true) {
      var newUnits = await Globals.db.unitDao.getWithLowerIdThan(lowestId, batchSize);
      if (newUnits.isEmpty) break;

      var toAdd = <Unit>[];
      for (var unit in newUnits) {
        if (filter == null || filter(unit)) toAdd.add(unit);
        if (unit.id < lowestId) lowestId = unit.id;

        if (limit != null && toAdd.length + units.length >= limit) break;
      }

      units.addAll(toAdd);
      if ((limit != null && units.length >= limit) || newUnits.length < batchSize) break;
    }

    var stations = Station.getAll();
    Map<int, Station> stationMap = {};
    for (var station in await stations) {
      stationMap[station.id] = station;
    }

    units.sort((a, b) => a.unitCallSign(stationMap[a.stationId]!).compareTo(b.unitCallSign(stationMap[b.stationId]!)));

    return units;
  }

  static Future<List<Unit>> getAll({bool Function(Unit)? filter}) => getBatched(filter: filter);

  static Future<void> update(Unit unit, bool bc) async {
    var existing = await Globals.db.unitDao.getById(unit.id);
    if (existing != null) {
      if (existing.updated >= unit.updated) return;
      await Globals.db.unitDao.updates(unit);
    } else {
      await Globals.db.unitDao.inserts(unit);
    }

    if (!bc) return;
    UpdateInfo(UpdateType.unit, {unit.id});
  }

  static Future<void> delete(int unitId, bool bc) async {
    await Globals.db.unitDao.deleteById(unitId);

    if (!bc) return;
    UpdateInfo(UpdateType.unit, {unitId});
  }
}

enum UnitPosition {
  zf,
  bf,
  ma,
  gf,
  atf,
  atm,
  wtf,
  wtm,
  stf,
  stm,
  me;
}
