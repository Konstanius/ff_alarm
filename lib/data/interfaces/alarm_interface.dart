import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';

abstract class AlarmInterface {
  static Future<void> fetchAll() async {
    Request response = await Request('alarmGetAll', {}).emit(true);
    
    var futures = <Future>[];
    for (Map<String, dynamic> alarm in response.data['alarms']) {
      Alarm newAlarm = Alarm.fromJson(alarm);
      futures.add(Globals.db.alarmDao.inserts(newAlarm));
      
      if (futures.length > 25) {
        await Future.wait(futures);
        futures = <Future>[];
      }
    }
    
    await Future.wait(futures);
  }
}
