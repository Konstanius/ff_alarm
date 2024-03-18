import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key, required this.badge});

  final ValueNotifier<int> badge;

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> with AutomaticKeepAliveClientMixin, Updates {
  @override
  bool get wantKeepAlive => true;

  List<Alarm> alarms = [];

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.alarm});

    Alarm.getBatched(limit: 25).then((List<Alarm> value) {
      if (!mounted) return;
      value.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        alarms = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          ElevatedButton(
            onPressed: () async {
              await Request('test', {}).emit(true);
            },
            child: const Text('Test Alarmierung'),
          ),
          for (Alarm alarm in alarms)
            ListTile(
              title: Text('${alarm.type} | ${alarm.word}'),
              subtitle: Text(alarm.date.toLocal().toString()),
              onTap: () {
                Globals.router.push('/alarm', extra: alarm);
              },
            ),
        ],
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) async {
    DateTime lowest = DateTime.now().subtract(const Duration(minutes: 20));
    for (var alarm in this.alarms) {
      if (alarm.date.isBefore(lowest)) lowest = alarm.date;
    }

    var alarms = <Alarm>[];
    var futures = <Future<Alarm?>>[];
    for (int id in info.ids) {
      futures.add(Globals.db.alarmDao.getById(id));
    }

    var values = await Future.wait(futures);
    for (var value in values) {
      if (value == null) continue;
      if (value.date.isBefore(lowest)) continue;
      alarms.add(value);
    }

    for (var alarm in alarms) {
      var index = this.alarms.indexWhere((element) => element.id == alarm.id);
      if (index != -1) {
        this.alarms[index] = alarm;
      } else {
        this.alarms.add(alarm);
      }
    }

    this.alarms.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {});
  }
}
