import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

abstract class AlarmInterface {
  static Future<void> fetchAll() async {
    DateTime archiveDate = DateTime.now().subtract(const Duration(days: 90));
    var allAlarms = await Alarm.getAll(filter: (alarm) => alarm.date.isAfter(archiveDate));

    StringBuffer sb = StringBuffer();
    for (Alarm alarm in allAlarms) {
      sb.write(alarm.id);
      sb.write(':');
      sb.write(alarm.updated);
      sb.write(',');
    }

    Map<String, dynamic> alarms = {'data': sb.toString()};

    Request response = await Request('alarmGetAll', alarms).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<int> updatedIds = {};
    var futures = <Future>[];
    for (Map<String, dynamic> alarm in response.ackData!['updated']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      Alarm newAlarm = Alarm.fromJson(alarm);
      futures.add(Alarm.update(newAlarm, false));
      updatedIds.add(newAlarm.id);
    }

    for (int id in response.ackData!['deleted']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      futures.add(Alarm.delete(id, false));
      updatedIds.remove(id);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.alarm, updatedIds);
  }

  static Future<Alarm> setResponse(Alarm alarm, AlarmResponse res) async {
    var json = res.toJson();
    json['alarmId'] = alarm.id;

    Request response = await Request('alarmSetResponse', json).emit(true);

    Alarm newAlarm = Alarm.fromJson(response.ackData!);
    await Alarm.update(newAlarm, true);

    return newAlarm;
  }

  static Future<({Alarm alarm, List<Unit> units, List<Station> stations, List<Person> persons})> getDetails(Alarm alarm) async {
    var queryUnits = await Globals.db.database.query(
      "Unit",
      columns: ["id", "updated", "stationId"],
      where: "id IN (${alarm.units.join(',')})",
    );
    List<String> unitInfo = [];
    Set<int> unitIds = {};
    for (Map<String, dynamic> unit in queryUnits) {
      unitInfo.add('${unit['id']}:${unit['updated']}');
      unitIds.add(unit['id']);
    }

    Set<int> stationIds = {};
    for (Map<String, dynamic> unit in queryUnits) {
      stationIds.add(unit['stationId']);
    }

    var queryStations = await Globals.db.database.query(
      "Station",
      columns: ["id", "updated"],
      where: "id IN (${stationIds.join(',')})",
    );
    List<String> stationInfo = [];
    for (Map<String, dynamic> station in queryStations) {
      stationInfo.add('${station['id']}:${station['updated']}');
    }

    var queryPersons = await Globals.db.database.query(
      "Person",
      columns: ["id", "updated"],
      where: "id IN (${alarm.responses.keys.join(',')})",
    );
    List<String> personInfo = [];
    Set<int> personIds = {};
    for (Map<String, dynamic> person in queryPersons) {
      personInfo.add('${person['id']}:${person['updated']}');
      personIds.add(person['id']);
    }

    Map<String, dynamic> data = {
      'alarm': '${alarm.id}:${alarm.updated}',
      'units': unitInfo.join(','),
      'stations': stationInfo.join(','),
      'persons': personInfo.join(','),
    };

    Request response = await Request('alarmGetDetails', data).emit(true);

    Alarm returnAlarm;
    if (response.ackData!['alarm'] != null) {
      returnAlarm = Alarm.fromJson(response.ackData!['alarm']);
      await Alarm.update(returnAlarm, true);
    } else {
      returnAlarm = alarm;
    }

    var returnObject = (
      alarm: returnAlarm,
      units: <Unit>[],
      stations: <Station>[],
      persons: <Person>[],
    );

    var futures = <Future>[];
    Set<int> updatedUnitIds = {};
    Set<int> updatedStationIds = {};
    Set<int> updatedPersonIds = {};

    if (response.ackData!['units'] != null) {
      for (Map<String, dynamic> unit in response.ackData!['units']) {
        Unit newUnit = Unit.fromJson(unit);
        returnObject.units.add(newUnit);

        if (unitIds.contains(newUnit.id)) {
          futures.add(Unit.update(newUnit, false));
          updatedUnitIds.add(newUnit.id);
        }
      }
    }

    if (response.ackData!['stations'] != null) {
      for (Map<String, dynamic> station in response.ackData!['stations']) {
        Station newStation = Station.fromJson(station);
        returnObject.stations.add(newStation);

        if (stationIds.contains(newStation.id)) {
          futures.add(Station.update(newStation, false));
          updatedStationIds.add(newStation.id);
        }
      }
    }

    if (response.ackData!['persons'] != null) {
      for (Map<String, dynamic> person in response.ackData!['persons']) {
        Person newPerson = Person.fromJson(person);
        returnObject.persons.add(newPerson);

        if (personIds.contains(newPerson.id)) {
          futures.add(Person.update(newPerson, false));
          updatedPersonIds.add(newPerson.id);
        }
      }
    }

    Future.wait(futures).then((_) {
      if (updatedUnitIds.isNotEmpty) UpdateInfo(UpdateType.unit, updatedUnitIds);
      if (updatedStationIds.isNotEmpty) UpdateInfo(UpdateType.station, updatedStationIds);
      if (updatedPersonIds.isNotEmpty) UpdateInfo(UpdateType.person, updatedPersonIds);
    });

    return returnObject;
  }
}
