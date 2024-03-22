import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/ui/utils/format.dart';
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
  Set<AlarmResponseType> clickIndices = {};

  Timer? clickTimer;
  bool timerBusy = false;

  bool loading = true;

  List<Unit> units = [];
  List<Station> stations = [];
  int? selectedStation;
  bool newAnswer = false;
  late Alarm alarm;

  ({Alarm alarm, List<Unit> units, List<Station> stations, List<Person> persons})? data;

  @override
  void initState() {
    super.initState();
    AlarmPage.currentAlarmId = widget.alarm.id;
    alarm = widget.alarm;

    AlarmInterface.getDetails(alarm).then((value) {
      data = value;
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    });

    setupListener({UpdateType.alarm, UpdateType.ui});

    clickTimer = Timer.periodic(const Duration(milliseconds: 10), (Timer timer) async {
      if (timerBusy) return;
      if (clickIndices.length == 1) {
        clickDuration.value = clickDuration.value + 10;
        if (clickDuration.value >= 1000) {
          timerBusy = true;
          AlarmResponseType type = clickIndices.first;

          try {
            await resetAndroidNotificationVolume();
            await AwesomeNotifications().dismissNotificationsByChannelKey('alarm');
            await AwesomeNotifications().dismissNotificationsByChannelKey('test');
            await AwesomeNotifications().cancelNotificationsByChannelKey('alarm');
            await AwesomeNotifications().cancelNotificationsByChannelKey('test');

            try {
              AlarmResponse response = AlarmResponse(
                type: type,
                note: null, // TODO
                stationId: type == AlarmResponseType.notReady ? null : selectedStation,
                time: DateTime.now(),
              );
              await AlarmInterface.setResponse(alarm, response);
            } catch (e, s) {
              Logger.error('Error setting alarm response: $e\n$s');
              return;
            }

            newAnswer = false;

            successToast('Alarm bestätigt: ${type.name}');

            clickDuration.value = 0;
          } catch (e) {
            errorToast('Fehler beim Bestätigen des Alarms: $e');
          } finally {
            timerBusy = false;
            if (mounted) setState(() {});
          }
        }
      } else {
        clickDuration.value = 0;
      }
    });

    // Sets up the alarm
    () async {
      var unitFutures = <Future<Unit?>>[];
      if (alarm.units.isNotEmpty) {
        for (int id in alarm.units) {
          if (!Globals.person!.allowedUnits.contains(id)) continue;
          unitFutures.add(Globals.db.unitDao.getById(id));
        }
      } else {
        for (int id in Globals.person!.allowedUnits) {
          unitFutures.add(Globals.db.unitDao.getById(id));
        }
      }
      var unitValues = await Future.wait(unitFutures);
      for (var value in unitValues) {
        if (value != null) units.add(value);
      }

      var stationFutures = <Future<Station?>>[];
      for (int id in units.map((e) => e.stationId).toSet()) {
        stationFutures.add(Globals.db.stationDao.getById(id));
      }
      var stationValues = await Future.wait(stationFutures);
      for (var value in stationValues) {
        if (value != null) stations.add(value);
      }

      if (alarm.responses.containsKey(Globals.person!.id)) {
        selectedStation = alarm.responses[Globals.person!.id]!.stationId;
      }
      if (stations.length == 1 && selectedStation == null) {
        selectedStation = stations.first.id;
      }

      stations.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }()
        .catchError((e, s) {
      Logger.error('Error loading stations for alarm: $e, $s');
      Navigator.of(Globals.context!).pop();
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
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (stations.length > 1 && selectedStation == null) return stationSelectionScreen();
    if (!alarm.responses.containsKey(Globals.person!.id) || newAnswer) return responseSelectionScreen();
    return alarmMonitorScreen();
  }

  Widget stationSelectionScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station auswählen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          // TODO a button to set response to no, without selecting a station
          for (var station in stations)
            // required to display:
            // name
            // address
            // dispatched units of station
            // distance (coordinates)
            // amount of ppl that said yes
            Card(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              color: selectedStation == station.id ? Colors.blue : Theme.of(context).focusColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8),
              elevation: selectedStation == station.id ? 5 : 0,
              child: ListTile(
                splashColor: Colors.blue,
                title: Text("${station.name} (${station.prefix} ${station.area} ${station.stationNumber})"),
                subtitle: () {
                  var stationPosition = station.position;

                  var dispatchedUnits = <Unit>[];
                  for (var unit in units) {
                    if (unit.stationId == station.id) dispatchedUnits.add(unit);
                  }

                  dispatchedUnits.sort((a, b) => a.unitCallSign(station).compareTo(b.unitCallSign(station)));

                  List<int> responses = [
                    0, // onStation
                    0, // under5
                    0, // under10
                    0, // under15
                    0, // onCall
                    0, // notReady
                    0, // notResponded
                  ];
                  for (var person in station.persons) {
                    if (alarm.responses.containsKey(person)) {
                      var response = alarm.responses[person]!;
                      if (response.stationId == station.id) {
                        responses[response.type.index]++;
                      } else {
                        responses[5]++;
                      }
                    } else {
                      responses[6]++;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 15),
                                const SizedBox(width: 5),
                                Flexible(child: Text(station.address, softWrap: true)),
                              ],
                            ),
                          ),
                          if (stationPosition != null && Globals.lastPosition != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.route_outlined, size: 15),
                                const SizedBox(width: 5),
                                Text(Formats.distanceBetween(Globals.lastPosition!, stationPosition)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Divider(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Antworten:', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center)]),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AlarmResponseType.onStation.color),
                                    const SizedBox(width: 5),
                                    Text('(vor Ort) ${responses[0]}'),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AlarmResponseType.under10.color),
                                    const SizedBox(width: 5),
                                    Text('(<10 min) ${responses[2]}'),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AlarmResponseType.onCall.color),
                                    const SizedBox(width: 5),
                                    Text('(Abruf) ${responses[4]}'),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.circle, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Text('(Unklar) ${responses[6]}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AlarmResponseType.under5.color),
                                    const SizedBox(width: 5),
                                    Text('(<5 min) ${responses[1]}'),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AlarmResponseType.under15.color),
                                    const SizedBox(width: 5),
                                    Text('(<15 min) ${responses[3]}'),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AlarmResponseType.notReady.color),
                                    const SizedBox(width: 5),
                                    Text('(Nein) ${responses[5]}'),
                                  ],
                                ),
                                const Row(mainAxisSize: MainAxisSize.min, children: [Text('')]),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Divider(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Alarmierte Einheiten:', style: Theme.of(context).textTheme.titleMedium)]),
                      const SizedBox(height: 5),
                      for (var unit in dispatchedUnits)
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(unit.unitCallSign(station)),
                            const SizedBox(width: 5),
                            Text(unit.unitDescription),
                          ],
                        ),
                    ],
                  );
                }(),
                onTap: () {
                  setState(() {
                    selectedStation = station.id;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget responseSelectionScreen() {
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
                    valueColor: clickIndices.length == 1 ? AlwaysStoppedAnimation<Color>(clickIndices.first.color) : const AlwaysStoppedAnimation<Color>(Colors.transparent),
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
                clickField(AlarmResponseType.onStation),
                clickField(AlarmResponseType.under5),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                clickField(AlarmResponseType.under10),
                clickField(AlarmResponseType.under15),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                clickField(AlarmResponseType.onCall),
                clickField(AlarmResponseType.notReady),
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

  Widget clickField(AlarmResponseType type) {
    String upper = type.name;
    return SizedBox(
      width: MediaQuery.of(context).size.width / 3,
      height: MediaQuery.of(context).size.width / 3,
      child: GestureDetector(
        onTapDown: (TapDownDetails details) {
          clickIndices.add(type);
        },
        onTapUp: (TapUpDetails details) {
          clickIndices.remove(type);
        },
        onTapCancel: () {
          clickIndices.remove(type);
        },
        child: Pulsator(
          style: PulseStyle(color: type.color),
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
              color: type.color,
            ),
            child: Center(
              child: Text(
                upper,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget alarmMonitorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmüberwachung'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // reset response -> set station to null
            ElevatedButton(
              onPressed: () async {
                if (mounted) {
                  setState(() {
                    selectedStation = null;
                    newAnswer = true;
                    if (stations.length == 1) {
                      selectedStation = stations.first.id;
                    }
                  });
                }
              },
              child: const Text('Zurücksetzen'),
            ),
            const SizedBox(height: 20),
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
    } else if (info.type == UpdateType.ui) {
      if (info.ids.contains(2)) {
        if (mounted) setState(() {});
      }

      if (info.ids.contains(0)) {
        AlarmInterface.getDetails(alarm).then((value) {
          data = value;
          if (!mounted) return;
          setState(() {
            loading = false;
          });
        });
      }
    }
  }
}

enum AlarmResponseType {
  onStation(0),
  under5(5),
  under10(10),
  under15(15),
  onCall(-1),
  notReady(-2);

  final int timeAmount;

  const AlarmResponseType(this.timeAmount);

  Color get color {
    switch (this) {
      case AlarmResponseType.onStation:
        return Colors.green;
      case AlarmResponseType.under5:
        return Colors.cyanAccent;
      case AlarmResponseType.under10:
        return Colors.yellow;
      case AlarmResponseType.under15:
        return Colors.orange;
      case AlarmResponseType.onCall:
        return Colors.purpleAccent;
      case AlarmResponseType.notReady:
        return Colors.red;
    }
  }

  String get name {
    switch (this) {
      case AlarmResponseType.onStation:
        return 'An Wache';
      case AlarmResponseType.under5:
        return '< 5 Min';
      case AlarmResponseType.under10:
        return '< 10 Min';
      case AlarmResponseType.under15:
        return '< 15 Min';
      case AlarmResponseType.onCall:
        return 'Auf Abruf dazu';
      case AlarmResponseType.notReady:
        return 'Nicht bereit';
    }
  }
}
