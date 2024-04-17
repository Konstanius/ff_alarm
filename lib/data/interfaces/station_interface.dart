import 'package:ff_alarm/data/models/station.dart';
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
}
