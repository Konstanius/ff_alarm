import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

import '../../globals.dart';

abstract class UnitInterface {
  static Future<void> fetchAll() async {
    var allUnits = await Unit.getAll();

    var servers = Globals.registeredServers;
    var futures = <Future>[];
    for (var server in servers) {
      List<Unit> serverUnits = allUnits.where((unit) => unit.server == server).toList();
      futures.add(fetchAllForServer(server, serverUnits));
    }

    await Future.wait(futures);
  }

  static Future<void> fetchAllForServerSilent(String server) async {
    List<Unit> serverUnits = await Globals.db.unitDao.getWithPrefix(server);
    await fetchAllForServer(server, serverUnits);
  }

  static Future<void> fetchAllForServer(String server, List<Unit> serverUnits) async {
    StringBuffer sb = StringBuffer();
    for (Unit unit in serverUnits) {
      sb.write(unit.idNumber);
      sb.write(':');
      sb.write(unit.updated);
      sb.write(',');
    }

    Map<String, dynamic> units = {'data': sb.toString()};

    Request response = await Request('unitGetAll', units, server).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<String> updatedIds = {};
    var futures = <Future>[];
    for (Map<String, dynamic> unit in response.ackData!['updated']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      Unit newUnit = Unit.fromJson(unit);
      futures.add(Unit.update(newUnit, false));
      updatedIds.add(newUnit.id);
    }

    for (int id in response.ackData!['deleted']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      String idString = "$server $id";

      futures.add(Unit.delete(idString, false));
      updatedIds.add(idString);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.unit, updatedIds);
  }

  static Future<List<Unit>> fetchForStationAsAdmin(String server, int stationId) async {
    Request response = await Request('unitGetForStation', {'stationId': stationId}, server).emit(true);

    List<Unit> units = [];
    for (Map<String, dynamic> unit in response.ackData!['units']) {
      units.add(Unit.fromJson(unit));
    }

    return units;
  }
}
