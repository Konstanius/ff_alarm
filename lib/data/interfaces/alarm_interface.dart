import 'dart:io';

import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/popups/alarm_info.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

import '../../globals.dart';

abstract class AlarmInterface {
  static Future<void> fetchAll() async {
    DateTime archiveDate = DateTime.now().subtract(const Duration(days: 90));
    var allAlarms = await Alarm.getAll(filter: (alarm) => alarm.date.isAfter(archiveDate));

    var servers = Globals.registeredServers;
    var futures = <Future>[];
    for (var server in servers) {
      List<Alarm> serverAlarms = allAlarms.where((alarm) => alarm.server == server).toList();
      futures.add(fetchAllForServer(server, serverAlarms));
    }

    await Future.wait(futures);
  }

  static Future<void> fetchAllForServer(String server, List<Alarm> nonArchivedAlarms) async {
    StringBuffer sb = StringBuffer();
    for (Alarm alarm in nonArchivedAlarms) {
      sb.write(alarm.idNumber);
      sb.write(':');
      sb.write(alarm.updated);
      sb.write(',');
    }

    Map<String, dynamic> alarms = {'data': sb.toString()};

    Request response = await Request('alarmGetAll', alarms, server).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<String> updatedIds = {};
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

      String idString = "$server $id";

      futures.add(Alarm.delete(idString, false));
      updatedIds.add(idString);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.alarm, updatedIds);
  }

  static Future<void> fetchSingle(String server, int id) async {
    Map<String, dynamic> data = {'alarmId': id};

    Request response = await Request('alarmGet', data, server).emit(true);
    if (response.ackData!.isEmpty) return;

    Alarm newAlarm = Alarm.fromJson(response.ackData!);
    await Alarm.update(newAlarm, true);
  }

  static Future<Alarm> setResponse({
    required String server,
    required int alarmId,
    required AlarmResponseType responseType,
    required int? stationId,
    required String note,
  }) async {
    if (stationId == null && responseType != AlarmResponseType.notReady) {
      throw AckError(HttpStatus.badRequest, "Du musst eine Wache angeben, wenn du eine Antwort gibst.");
    }

    Map<String, dynamic> data = {
      "alarmId": alarmId,
      "responseType": responseType.index,
      "stationId": stationId,
      "note": note,
    };

    Request response = await Request('alarmSetResponse', data, server).emit(true);

    Alarm newAlarm = Alarm.fromJson(response.ackData!);
    await Alarm.update(newAlarm, true);

    return newAlarm;
  }

  static Future<({Alarm alarm, List<Unit> units, List<Station> stations, List<Person> persons})> getDetails(Alarm alarm) async {
    var existingUnits = await Unit.getBatched(filter: (unit) => alarm.unitProperIds.contains(unit.id));
    Set<String> unitIds = {};
    for (var unit in existingUnits) {
      unitIds.add(unit.id);
    }

    Set<String> stationIds = {};
    for (var unit in existingUnits) {
      stationIds.add(unit.stationProperId);
    }

    var existingStations = await Station.getBatched(filter: (station) => stationIds.contains(station.id));
    Set<String> personIds = {};
    for (var station in existingStations) {
      personIds.addAll(station.personProperIds);
    }

    var existingPersons = await Person.getBatched(filter: (person) => personIds.contains(person.id) && person.allowedUnits.any((unitId) => alarm.units.contains(unitId)));

    Set<String> unitInfo = {};
    for (var unit in existingUnits) {
      unitInfo.add('${unit.idNumber}:${unit.updated}');
    }

    Set<String> stationInfo = {};
    for (var station in existingStations) {
      stationInfo.add('${station.idNumber}:${station.updated}');
    }

    Set<String> personInfo = {};
    for (var person in existingPersons) {
      personInfo.add('${person.idNumber}:${person.updated}');
    }

    Map<String, dynamic> data = {
      'alarm': '${alarm.idNumber}:${alarm.updated}',
      'units': unitInfo.join(','),
      'stations': stationInfo.join(','),
      'persons': personInfo.join(','),
    };

    Request response = await Request('alarmGetDetails', data, alarm.server).emit(true);

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
    Set<String> updatedUnitIds = {};
    Set<String> updatedStationIds = {};
    Set<String> updatedPersonIds = {};

    if (response.ackData!['units'] != null) {
      for (Map<String, dynamic> unit in response.ackData!['units']) {
        Unit newUnit = Unit.fromJson(unit);
        returnObject.units.add(newUnit);

        if (unitIds.contains(newUnit.id)) {
          futures.add(Unit.update(newUnit, false));
          updatedUnitIds.add(newUnit.id);
          existingUnits.removeWhere((element) => element.id == newUnit.id);
        }
      }
    }

    returnObject.units.addAll(existingUnits);

    if (response.ackData!['stations'] != null) {
      for (Map<String, dynamic> station in response.ackData!['stations']) {
        Station newStation = Station.fromJson(station);
        returnObject.stations.add(newStation);

        if (stationIds.contains(newStation.id)) {
          futures.add(Station.update(newStation, false));
          updatedStationIds.add(newStation.id);
          existingStations.removeWhere((element) => element.id == newStation.id);
        }
      }
    }

    returnObject.stations.addAll(existingStations);

    if (response.ackData!['persons'] != null) {
      for (Map<String, dynamic> person in response.ackData!['persons']) {
        Person newPerson = Person.fromJson(person);
        returnObject.persons.add(newPerson);

        if (personIds.contains(newPerson.id)) {
          futures.add(Person.update(newPerson, false));
          updatedPersonIds.add(newPerson.id);
          existingPersons.removeWhere((element) => element.id == newPerson.id);
        }
      }
    }

    returnObject.persons.addAll(existingPersons);

    Future.wait(futures).then((_) {
      if (updatedUnitIds.isNotEmpty) UpdateInfo(UpdateType.unit, updatedUnitIds);
      if (updatedStationIds.isNotEmpty) UpdateInfo(UpdateType.station, updatedStationIds);
      if (updatedPersonIds.isNotEmpty) UpdateInfo(UpdateType.person, updatedPersonIds);
    });

    return returnObject;
  }
}
