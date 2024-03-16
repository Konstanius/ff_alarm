import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

abstract class StationInterface {
  static Future<void> fetchAll() async {
    var allStations = await Station.getAll();
    Map<String, dynamic> stations = {};
    for (Station station in allStations) {
      stations[station.id.toString()] = station.updated.millisecondsSinceEpoch;
    }

    Request response = await Request('stationGetAll', stations).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<int> updatedIds = {};
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

      futures.add(Station.delete(id, false));
      updatedIds.remove(id);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.station, updatedIds);
  }
}
