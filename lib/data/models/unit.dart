import 'package:ff_alarm/data/models/station.dart';
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

  DateTime updated;

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
      positions: json[jsonShorts["positions"]].map((e) => UnitPosition.values[e]).toList(),
      capacity: json[jsonShorts["capacity"]],
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
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
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  String unitCallSign(Station station) {
    return "${station.prefix} ${station.area} ${station.stationNumber}-$unitType-$unitIdentifier";
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
