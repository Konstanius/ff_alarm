import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> with AutomaticKeepAliveClientMixin, Updates {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.alarm});
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
          for (Alarm alarm in [])
            ListTile(
              title: Text('${alarm.type} | ${alarm.word}'),
              subtitle: Text(alarm.date.toLocal().toString()),
              onTap: () {},
            ),
          ElevatedButton(
            onPressed: () async {
              await Request('test', {}).emit(true);
            },
            child: const Text('Test Alarmierung'),
          ),
        ],
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) {
    // TODO: implement onUpdate
  }
}
