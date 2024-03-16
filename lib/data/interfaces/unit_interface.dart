import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';

abstract class UnitInterface {
  static Future<void> fetchAll() async {
    Request response = await Request('alarmGetAll', {}).emit(true);

    var futures = <Future>[];
    for (Map<String, dynamic> unit in response.data['units']) {
      Unit newUnit = Unit.fromJson(unit);
      futures.add(Globals.db.unitDao.inserts(newUnit));

      if (futures.length > 25) {
        await Future.wait(futures);
        futures = <Future>[];
      }
    }

    await Future.wait(futures);
  }
}