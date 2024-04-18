import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

import '../../globals.dart';

abstract class StationInterface {
  static Future<void> fetchAll() async {
    var allStations = await Station.getAll();

    var servers = Globals.registeredServers;
    var futures = <Future>[];
    for (var server in servers) {
      List<Station> serverStations = allStations.where((station) => station.server == server).toList();
      futures.add(fetchAllForServer(server, serverStations));
    }

    await Future.wait(futures);
  }

  static Future<void> fetchAllForServerSilent(String server) async {
    List<Station> serverStations = await Globals.db.stationDao.getWithServer(server);
    await fetchAllForServer(server, serverStations);
  }

  static Future<void> fetchAllForServer(String server, List<Station> serverStations) async {
    StringBuffer sb = StringBuffer();
    for (Station station in serverStations) {
      sb.write(station.idNumber);
      sb.write(':');
      sb.write(station.updated);
      sb.write(',');
    }

    Map<String, dynamic> stations = {'data': sb.toString()};

    Request response = await Request('stationGetAll', stations, server).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<String> updatedIds = {};
    var futures = <Future>[];
    for (Map<String, dynamic> station in response.ackData!['updated']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      Station newStation = Station.fromJson(station);
      futures.add(Station.update(newStation, false));
      updatedIds.add(newStation.id);
    }

    for (int id in response.ackData!['deleted']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      String idString = "$server $id";

      futures.add(Station.delete(idString, false));
      updatedIds.add(idString);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.station, updatedIds);
  }

  static Future<Map<String, dynamic>> getNotifyInformation(List<String> servers) async {
    List<Future> futures = [];
    Map<String, dynamic> result = {};
    for (String server in servers) {
      String copy = server;
      futures.add(() async {
        try {
          Request response = await Request('stationGetNotifyModes', {}, server).emit(true);
          for (var entry in response.ackData!.entries) {
            result['$copy ${entry.key}'] = entry.value;
          }
        } catch (e, s) {
          Logger.error('Failed to get notify information for $server: $e\n$s');
        }
      }());
    }

    await Future.wait(futures);

    return result;
  }

  static Future<void> setAdmin({required bool toAdmin, required String server, required int stationId, required int personId}) async {
    Map<String, dynamic> data = {
      'stationId': stationId,
      'personId': personId,
      'toAdmin': toAdmin,
    };

    Request response = await Request('stationSetAdmin', data, server).emit(true);

    Station station = Station.fromJson(response.ackData!);
    await Station.update(station, true);
  }

  static Future<void> addPerson({required String server, required int stationId, required int personId}) async {
    Map<String, dynamic> data = {
      'stationId': stationId,
      'personId': personId,
    };

    Request response = await Request('stationAddPerson', data, server).emit(true);

    Station station = Station.fromJson(response.ackData!);
    await Station.update(station, true);
  }

  static Future<void> removePerson({required String server, required int stationId, required int personId}) async {
    Map<String, dynamic> data = {
      'stationId': stationId,
      'personId': personId,
    };

    Request response = await Request('stationRemovePerson', data, server).emit(true);

    Station station = Station.fromJson(response.ackData!);
    await Station.update(station, true);
  }
}
