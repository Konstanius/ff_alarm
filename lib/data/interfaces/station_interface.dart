import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';

abstract class StationInterface {
  static Future<void> fetchAll() async {
    Request response = await Request('alarmGetAll', {}).emit(true);

    var futures = <Future>[];
    for (Map<String, dynamic> station in response.data['stations']) {
      Station newStation = Station.fromJson(station);
      futures.add(Globals.db.stationDao.inserts(newStation));

      if (futures.length > 25) {
        await Future.wait(futures);
        futures = <Future>[];
      }
    }

    await Future.wait(futures);
  }
}
