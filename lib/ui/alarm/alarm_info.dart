import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:pulsator/pulsator.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, required this.alarm});

  final Alarm alarm;

  static int? currentAlarmId;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> with Updates {
  ValueNotifier<int> clickDuration = ValueNotifier<int>(0);
  Set<int> clickIndices = {};
  static const Map<int, Color> clickColors = {
    0: Colors.green,
    1: Colors.blue,
    2: Colors.yellow,
    3: Colors.orange,
    4: Colors.purpleAccent,
    5: Colors.red,
  };

  Timer? clickTimer;
  bool timerBusy = false;

  late Alarm alarm;

  @override
  void initState() {
    super.initState();
    AlarmPage.currentAlarmId = widget.alarm.id;
    alarm = widget.alarm;

    setupListener({UpdateType.alarm});

    clickTimer = Timer.periodic(const Duration(milliseconds: 10), (Timer timer) async {
      if (timerBusy) return;
      if (clickIndices.length == 1) {
        clickDuration.value = clickDuration.value + 10;
        if (clickDuration.value >= 1000) {
          timerBusy = true;
          int index = clickIndices.first;

          try {
            await resetAndroidNotificationVolume();
            await AwesomeNotifications().dismissNotificationsByChannelKey('alarm');
            await AwesomeNotifications().dismissNotificationsByChannelKey('test');
            await AwesomeNotifications().cancelNotificationsByChannelKey('alarm');
            await AwesomeNotifications().cancelNotificationsByChannelKey('test');

            try {
              AlarmResponse response = AlarmResponse(
                duration: clickDuration.value,
                note: null,
                stationId: 1,
                time: DateTime.now(),
              );
              await AlarmInterface.setResponse(alarm, response);
            } catch (e, s) {
              Logger.error('Error setting alarm response: $e\n$s');
              return;
            }

            successToast('Alarm bestätigt: $index');

            clickDuration.value = 0;
          } catch (e) {
            errorToast('Fehler beim Bestätigen des Alarms: $e');
          } finally {
            timerBusy = false;
          }
        }
      } else {
        clickDuration.value = 0;
      }
    });
  }

  @override
  void dispose() {
    AlarmPage.currentAlarmId = null;
    clickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Stack(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: clickDuration,
              builder: (BuildContext context, int value, Widget? child) {
                return Positioned.fill(
                  child: LinearProgressIndicator(
                    value: value / 1000,
                    backgroundColor: Colors.transparent,
                    valueColor: clickIndices.length == 1 ? AlwaysStoppedAnimation<Color>(clickColors[clickIndices.first]!) : const AlwaysStoppedAnimation<Color>(Colors.transparent),
                  ),
                );
              },
            ),
            AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Alarmierung'),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                clickField(upper: 'An Wache', index: 0),
                clickField(upper: '< 5 Min', index: 1),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                clickField(upper: '< 10 Min', index: 2),
                clickField(upper: '< 15 Min', index: 3),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                clickField(upper: 'Nicht\nEinsatzbereit', index: 4),
                clickField(upper: 'Auf Abruf\nnachkommen', index: 5),
              ],
            ),
            Text('Alarm: ${alarm.type}'),
            Text('Word: ${alarm.word}'),
            Text('Date: ${alarm.date}'),
            Text('Number: ${alarm.number}'),
            Text('Address: ${alarm.address}'),
            Text('Notes: ${alarm.notes}'),
            Text('Units: ${alarm.units}'),
            Text('Updated: ${alarm.updated}'),
            Text('Responses: ${alarm.responses}'),
          ],
        ),
      ),
    );
  }

  Widget clickField({required String upper, required int index}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 3,
      height: MediaQuery.of(context).size.width / 3,
      child: GestureDetector(
        onTapDown: (TapDownDetails details) {
          clickIndices.add(index);
        },
        onTapUp: (TapUpDetails details) {
          clickIndices.remove(index);
        },
        onTapCancel: () {
          clickIndices.remove(index);
        },
        child: ValueListenableBuilder<int>(
          valueListenable: clickDuration,
          builder: (BuildContext context, int value, Widget? child) {
            return Pulsator(
              style: PulseStyle(color: clickColors[index]!),
              count: 3,
              duration: const Duration(seconds: 6),
              repeat: 0,
              startFromScratch: true,
              autoStart: true,
              fit: PulseFit.cover,
              child: Container(
                width: MediaQuery.of(context).size.width / 3,
                height: MediaQuery.of(context).size.width / 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: clickColors[index],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.alarm && info.ids.contains(widget.alarm.id)) {
      var a = await Globals.db.alarmDao.getById(widget.alarm.id);
      if (!mounted) return;
      if (a == null) {
        Navigator.of(Globals.context!).pop();
      } else {
        alarm = a;
        setState(() {});
      }
    }
  }
}
