import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

abstract class UnitInterface {
  static Future<void> fetchAll() async {
    var allUnits = await Unit.getAll();
    Map<String, dynamic> units = {};
    for (Unit unit in allUnits) {
      units[unit.id.toString()] = unit.updated.millisecondsSinceEpoch;
    }

    Request response = await Request('unitGetAll', units).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<int> updatedIds = {};
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

      futures.add(Unit.delete(id, false));
      updatedIds.remove(id);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.unit, updatedIds);
  }
}
