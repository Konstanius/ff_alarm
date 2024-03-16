import 'dart:async';

import 'package:ff_alarm/data/converters.dart';
import 'package:ff_alarm/data/daos/alarm_dao.dart';
import 'package:ff_alarm/data/daos/person_dao.dart';
import 'package:ff_alarm/data/daos/station_dao.dart';
import 'package:ff_alarm/data/daos/unit_dao.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:floor/floor.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite/sqflite.dart' as sqflite;

part 'database.g.dart';

@TypeConverters([
  DateTimeConverter,
  ListStringConverter,
  ListIntConverter,
  NullableListIntConverter,
  MapIntAlarmResponseConverter,
  AlarmResponseConverter,
  ListUnitPositionConverter,
])
@Database(
  version: 1,
  entities: [
    Alarm,
    Station,
    Unit,
    Person,
  ],
)
abstract class AppDatabase extends FloorDatabase {
  AlarmDao get alarmDao;
  StationDao get stationDao;
  UnitDao get unitDao;
  PersonDao get personDao;
}

// ignore: library_private_types_in_public_api
extension BetterPathDatabaseExtension on _$AppDatabaseBuilder {
  /// Creates the database and initializes it.
  Future<AppDatabase> buildBetterPath() async {
    final String path = await getDatabasePath();
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }

  Future<String> getDatabasePath() async {
    String path = name != null ? '${Globals.filesPath}/databases/$name' : ':memory:';
    return path;
  }
}

Future<String> getDatabasePath(String name) async {
  return '${Globals.filesPath}/databases/$name';
}
