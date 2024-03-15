import 'package:ff_alarm/data/models/alarm.dart';
import 'package:flutter/material.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, required this.alarm});
  
  final Alarm alarm;
  
  static int? currentAlarmId;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  
  @override
  void initState() {
    AlarmPage.currentAlarmId = widget.alarm.id;
    super.initState();
  }
  
  @override
  void dispose() {
    AlarmPage.currentAlarmId = null;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmierung'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Alarm: ${widget.alarm.type}'),
            Text('Word: ${widget.alarm.word}'),
            Text('Date: ${widget.alarm.date}'),
            Text('Number: ${widget.alarm.number}'),
            Text('Address: ${widget.alarm.address}'),
            Text('Notes: ${widget.alarm.notes}'),
            Text('Units: ${widget.alarm.units}'),
          ],
        ),
      ),
    );
  }
}
