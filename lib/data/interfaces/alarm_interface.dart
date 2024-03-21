import 'package:ff_alarm/data/models/alarm.dart';
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

  static Future<Alarm> setResponse(Alarm alarm, AlarmResponse response) async {
    var json = response.toJson();
    json['alarmId'] = alarm.id;

    Request request = await Request('alarmSetResponse', json).emit(true);

    Alarm newAlarm = Alarm.fromJson(request.ackData!);
    await Alarm.update(newAlarm, true);

    return newAlarm;
  }
}
