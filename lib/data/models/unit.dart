import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';
import 'package:flutter/material.dart';

@entity
class Unit {
  @primaryKey
  final String id;
  String get server => id.split(' ')[0];
  int get idNumber => int.parse(id.split(' ')[1]);

  int stationId;
  String get stationProperId => "$server $stationId";

  int unitType;

  int unitIdentifier;

  String unitDescription;

  int status;
  UnitStatus get statusEnum => UnitStatus.fromInt(status);

  List<UnitPosition> positions;
  String get positionsDescription {
    int zf = 0;
    int gf = 0;
    int other = capacity;
    int total = capacity;

    for (var position in positions) {
      if (position == UnitPosition.zf) {
        zf++;
        other--;
      }
      if (position == UnitPosition.gf) {
        gf++;
        other--;
      }
    }

    if (gf == 0 && zf == 0 && positions.contains(UnitPosition.atf)) {
      other--;
      gf++;
    }

    String text = '$gf / $other / $total';
    if (zf > 0) text = '$zf / $text';

    return text;
  }

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
    "server": "s",
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
      id: "${json[jsonShorts["server"]]!} ${json[jsonShorts["id"]]!}",
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

  String callSign(Station station) {
    return "${station.prefix} ${station.area} ${station.stationNumber}-$unitType-$unitIdentifier";
  }

  static Future<List<Unit>> getBatched({
    bool Function(Unit)? filter,
    int? limit,
    String? startingId,
  }) async {
    var units = <Unit>[];

    String lowestId = startingId ?? "\u{10FFFF}";
    const batchSize = 50;
    while (true) {
      var newUnits = await Globals.db.unitDao.getWithLowerIdThan(lowestId, batchSize);
      if (newUnits.isEmpty) break;

      var toAdd = <Unit>[];
      for (var unit in newUnits) {
        if (filter == null || filter(unit)) toAdd.add(unit);
        if (unit.id.compareTo(lowestId) < 0) lowestId = unit.id;

        if (limit != null && toAdd.length + units.length >= limit) break;
      }

      units.addAll(toAdd);
      if ((limit != null && units.length >= limit) || newUnits.length < batchSize) break;
    }

    var stations = Station.getAll();
    Map<String, Station> stationMap = {};
    for (var station in await stations) {
      stationMap[station.id] = station;
    }

    units.sort((a, b) => a.callSign(stationMap[a.stationProperId]!).compareTo(b.callSign(stationMap[a.stationProperId]!)));

    return units;
  }

  static Future<List<Unit>> getAll({bool Function(Unit)? filter}) => getBatched(filter: filter);

  static Future<void> update(Unit unit, bool bc) async {
    // guarantee, that:
    // id contains a space
    // id split 0 != null
    // id split 1 != 0
    var splits = unit.id.split(' ');
    if (splits.length != 2 || splits[0].isEmpty || splits[1].isEmpty) return;
    if (splits[0] == 'null' || splits[1] == '0') return;
    if (int.tryParse(splits[1]) == null) return;

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

  static Future<void> delete(String unitId, bool bc) async {
    await Globals.db.unitDao.deleteById(unitId);

    if (!bc) return;
    UpdateInfo(UpdateType.unit, {unitId});
  }

  static Future<int?> getAmount(String server) => Globals.db.unitDao.getAmountWithPrefix(server);
}

enum UnitPosition {
  zf,
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

enum UnitStatus {
  invalid,
  onRadio,
  onStation,
  onRoute,
  onScene,
  notAvailable,
  toHospital,
  atHospital;

  static const Map<UnitStatus, int> sw = {
    UnitStatus.invalid: 0,
    UnitStatus.onRadio: 1,
    UnitStatus.onStation: 2,
    UnitStatus.onRoute: 3,
    UnitStatus.onScene: 4,
    UnitStatus.notAvailable: 6,
    UnitStatus.toHospital: 7,
    UnitStatus.atHospital: 8,
  };

  static UnitStatus fromInt(int status) {
    for (var entry in sw.entries) {
      if (entry.value == status) return entry.key;
    }
    return UnitStatus.invalid;
  }

  int get value => sw[this] ?? 0;

  IconData get icon {
    switch (this) {
      case UnitStatus.invalid:
        return Icons.question_mark_outlined;
      case UnitStatus.onRadio:
        return Icons.radio_outlined;
      case UnitStatus.onStation:
        return Icons.home_outlined;
      case UnitStatus.onRoute:
        return Icons.directions_outlined;
      case UnitStatus.onScene:
        return Icons.location_on_outlined;
      case UnitStatus.notAvailable:
        return Icons.block_outlined;
      case UnitStatus.toHospital:
        return Icons.emergency_outlined;
      case UnitStatus.atHospital:
        return Icons.local_hospital_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UnitStatus.invalid:
        return Colors.grey;
      case UnitStatus.onRadio:
        return Colors.blue;
      case UnitStatus.onStation:
        return Colors.green;
      case UnitStatus.onRoute:
      case UnitStatus.toHospital:
        return Colors.orange;
      case UnitStatus.onScene:
      case UnitStatus.atHospital:
        return Colors.red;
      case UnitStatus.notAvailable:
        return Colors.grey;
    }
  }

  String get description {
    switch (this) {
      case UnitStatus.invalid:
        return 'Ungültiger Status';
      case UnitStatus.onRadio:
        return 'Frei über Funk';
      case UnitStatus.onStation:
        return 'Auf Wache';
      case UnitStatus.onRoute:
        return 'Einsatz übernommen';
      case UnitStatus.onScene:
        return 'Am Einsatzort';
      case UnitStatus.notAvailable:
        return 'Nicht einsatzbereit';
      case UnitStatus.toHospital:
        return 'Patient aufgenommen';
      case UnitStatus.atHospital:
        return 'Am Zielort angekommen';
    }
  }
}
