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
import 'package:ff_alarm/ui/utils/map.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:pulsator/pulsator.dart';
import 'package:share_plus/share_plus.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, required this.alarm});

  final Alarm alarm;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> with Updates, SingleTickerProviderStateMixin {
  late Person relevantLocalPerson;

  ValueNotifier<int> clickDuration = ValueNotifier<int>(0);
  Set<AlarmResponseType> clickIndices = {};

  Timer? clickTimer;
  bool timerBusy = false;

  bool loading = true;

  List<Unit> units = [];
  List<Station> stations = [];
  String? selectedStation;
  bool newAnswer = false;
  late Alarm alarm;

  ({Alarm alarm, List<Unit> units, List<Station> stations, List<Person> persons})? data;
  TabController? tabController;

  LatLng? alarmPosition;
  ValueNotifier<List<MapPos>> informationNotifier = ValueNotifier<List<MapPos>>([]);
  MapController alarmMapController = MapController();

  bool alarmDetailsBusy = false;

  TextEditingController noteController = TextEditingController();
  FocusNode noteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    alarm = widget.alarm;
    tabController = TabController(length: 3, vsync: this);

    Person? tempRelevantLocalPerson;
    for (var person in Globals.localPersons.keys) {
      if (person.startsWith(alarm.server)) {
        tempRelevantLocalPerson = Globals.localPersons[person];
        break;
      }
    }
    if (tempRelevantLocalPerson == null) {
      Alarm.delete(alarm.id, true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(Globals.context!).pop();
      });
      return;
    }
    relevantLocalPerson = tempRelevantLocalPerson;

    fetchAlarmDetails();

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

            String? stationIdCopy = selectedStation;
            if (stationIdCopy == null && type != AlarmResponseType.notReady) {
              for (var station in stations) {
                if (station.personProperIds.contains(relevantLocalPerson.id)) {
                  stationIdCopy = station.id;
                  break;
                }
              }
            }

            if (type == AlarmResponseType.notReady) {
              stationIdCopy = null;
            }

            selectedStation = stationIdCopy;

            int? selectedStationId;
            if (stationIdCopy != null) {
              selectedStationId = int.parse(stationIdCopy.split(' ').last);
            }

            try {
              await AlarmInterface.setResponse(
                server: alarm.server,
                alarmId: alarm.idNumber,
                responseType: type,
                stationId: selectedStationId,
                note: '',
              );
              noteController.text = '';
              resetMapInfoNotifiers();
            } catch (e, s) {
              fetchAlarmDetails();
              exceptionToast(e, s);
              return;
            }

            newAnswer = false;

            successToast('Alarm bestätigt: ${type.name}');

            clickDuration.value = 0;
          } catch (e) {
            errorToast('Fehler beim Bestätigen des Alarms: $e');
          } finally {
            Future.delayed(const Duration(milliseconds: 200), () {
              timerBusy = false;
            });
            if (mounted) setState(() {});
          }
        }
      } else {
        clickDuration.value = 0;
      }
    });

    if (alarm.responses.containsKey(relevantLocalPerson.idNumber)) {
      noteController.text = alarm.responses[relevantLocalPerson.idNumber]!.note;
    }

    // Sets up the alarm
    () async {
      var unitFutures = <Future<Unit?>>[];
      if (alarm.units.isNotEmpty) {
        for (String id in alarm.unitProperIds) {
          if (!relevantLocalPerson.allowedUnitProperIds.contains(id)) continue;
          unitFutures.add(Globals.db.unitDao.getById(id));
        }
      } else {
        for (String id in relevantLocalPerson.allowedUnitProperIds) {
          unitFutures.add(Globals.db.unitDao.getById(id));
        }
      }
      var unitValues = await Future.wait(unitFutures);
      for (var value in unitValues) {
        if (value != null) units.add(value);
      }

      var stationFutures = <Future<Station?>>[];
      for (String id in units.map((e) => e.stationProperId).toSet()) {
        stationFutures.add(Globals.db.stationDao.getById(id));
      }
      var stationValues = await Future.wait(stationFutures);
      for (var value in stationValues) {
        if (value != null) stations.add(value);
      }

      if (stations.length == 1) {
        selectedStation = stations.first.id;
      } else if (alarm.responses.containsKey(relevantLocalPerson.idNumber) && alarm.responses[relevantLocalPerson.idNumber]!.responses.isNotEmpty) {
        selectedStation = null;
        for (var entry in alarm.responses[relevantLocalPerson.idNumber]!.responses.entries) {
          if (entry.value != AlarmResponseType.notReady && entry.value != AlarmResponseType.notSet) {
            selectedStation = "${alarm.server} ${entry.key}";
            break;
          }
        }
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

    const double maxZoom = 19;
    const double minZoom = 11;

    // Gets the alarm LatLng
    () async {
      // listen to the map controllers and reset the rotation on all move events
      alarmMapController.mapEventStream.listen((event) {
        if (event is MapEventMove) {
          alarmMapController.rotate(0);

          if (alarmMapController.camera.zoom < minZoom) {
            alarmMapController.move(alarmMapController.camera.center, minZoom);
          } else if (alarmMapController.camera.zoom > maxZoom) {
            alarmMapController.move(alarmMapController.camera.center, maxZoom);
          }
        }
      });

      while (true) {
        if (!mounted) return;
        try {
          Position? pos = alarm.positionFromAddressIfCoordinates;

          LatLng? position;
          if (pos != null) {
            position = Formats.positionToLatLng(pos);
          } else {
            position = await Formats.getCoordinates(alarm.address);
          }

          alarmPosition = position;
          resetMapInfoNotifiers();
          if (!mounted) return;
          setState(() {});
          break;
        } catch (e, s) {
          Logger.error('Error getting coordinates for alarm: $e\n$s');
        }

        await Future.delayed(const Duration(seconds: 1));
      }
    }();
  }

  @override
  void dispose() {
    clickTimer?.cancel();
    clickDuration.dispose();
    tabController?.dispose();
    informationNotifier.dispose();
    alarmMapController.dispose();
    noteController.dispose();
    noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text('Alarmierung'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    bool showAnswerScreen = newAnswer || (!alarm.responseTimeExpired && !alarm.responses.containsKey(relevantLocalPerson.idNumber));
    if (!showAnswerScreen && !alarm.responseTimeExpired && alarm.responses.containsKey(relevantLocalPerson.idNumber)) {
      var response = alarm.responses[relevantLocalPerson.idNumber]!;
      showAnswerScreen = response.responses.values.any((element) => element == AlarmResponseType.notSet);
    }
    if (selectedStation == null && stations.length > 1 && showAnswerScreen) return stationSelectionScreen();
    if (showAnswerScreen) return responseSelectionScreen();
    return alarmMonitorScreen();
  }

  Widget stationSelectionScreen() {
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
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          // direct large no button
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTapDown: (TapDownDetails details) {
                    clickIndices.add(AlarmResponseType.notReady);
                  },
                  onTapUp: (TapUpDetails details) {
                    clickIndices.remove(AlarmResponseType.notReady);
                  },
                  onTapCancel: () {
                    clickIndices.remove(AlarmResponseType.notReady);
                  },
                  child: Card(
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    color: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Nicht bereit', style: Theme.of(context).textTheme.headlineLarge),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(8),
              elevation: selectedStation == station.id ? 5 : 0,
              child: ListTile(
                splashColor: Colors.blue,
                title: Text("${station.name} (${station.prefix} ${station.area} ${station.stationNumber})"),
                subtitle: () {
                  var stationPosition = station.position;

                  var dispatchedUnits = <Unit>[];
                  for (var unit in units) {
                    if (unit.stationProperId == station.id) dispatchedUnits.add(unit);
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
                  if (data == null || alarm.units.isEmpty) {
                    for (var person in station.persons) {
                      if (alarm.responses.containsKey(person)) {
                        var response = alarm.responses[person]!;

                        if (response.responses.containsKey(station.idNumber)) {
                          responses[response.responses[station.idNumber]!.index]++;
                        } else {
                          responses[6]++;
                        }
                      } else {
                        responses[6]++;
                      }
                    }
                  } else {
                    for (var person in data!.persons) {
                      // check intersection for units
                      bool hasUnit = false;
                      for (var unit in dispatchedUnits) {
                        if (person.allowedUnitProperIds.contains(unit.id)) {
                          hasUnit = true;
                          break;
                        }
                      }
                      if (!hasUnit) continue;

                      if (alarm.responses.containsKey(person.idNumber)) {
                        var response = alarm.responses[person.idNumber]!;

                        if (response.responses.containsKey(station.idNumber)) {
                          responses[response.responses[station.idNumber]!.index]++;
                        } else {
                          responses[6]++;
                        }
                      } else {
                        responses[6]++;
                      }
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
          ...genericAlarmInfo(),
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
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: <Widget>[
            if (stations.length > 1)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedStation = null;
                  });
                },
                child: const Text('Zurück zur Wachenauswahl'),
              ),
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
            const SizedBox(height: 28),
            ...genericAlarmInfo(),
            () {
              Station? st;
              if (selectedStation != null) {
                for (var s in stations) {
                  if (s.id == selectedStation) {
                    st = s;
                    break;
                  }
                }
              } else {
                for (var s in stations) {
                  if (s.personProperIds.contains(relevantLocalPerson.id)) {
                    st = s;
                    break;
                  }
                }
              }

              if (st == null) return const SizedBox();
              Station station = st;

              return Card(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                color: Theme.of(context).focusColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                margin: const EdgeInsets.all(8),
                elevation: selectedStation == station.id ? 5 : 0,
                child: ListTile(
                  splashColor: Colors.blue,
                  title: Text("${station.name} (${station.prefix} ${station.area} ${station.stationNumber})"),
                  subtitle: () {
                    var stationPosition = station.position;

                    var dispatchedUnits = <Unit>[];
                    for (var unit in units) {
                      if (unit.stationProperId == station.id) dispatchedUnits.add(unit);
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
                    if (data == null || alarm.units.isEmpty) {
                      for (var person in station.persons) {
                        if (alarm.responses.containsKey(person)) {
                          var response = alarm.responses[person]!;

                          if (response.responses.containsKey(station.idNumber)) {
                            responses[response.responses[station.idNumber]!.index]++;
                          } else {
                            responses[6]++;
                          }
                        } else {
                          responses[6]++;
                        }
                      }
                    } else {
                      for (var person in data!.persons) {
                        // check intersection for units
                        bool hasUnit = false;
                        for (var unit in dispatchedUnits) {
                          if (person.allowedUnitProperIds.contains(unit.id)) {
                            hasUnit = true;
                            break;
                          }
                        }
                        if (!hasUnit) continue;

                        if (alarm.responses.containsKey(person.idNumber)) {
                          var response = alarm.responses[person.idNumber]!;

                          if (response.responses.containsKey(station.idNumber)) {
                            responses[response.responses[station.idNumber]!.index]++;
                          } else {
                            responses[6]++;
                          }
                        } else {
                          responses[6]++;
                        }
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
                ),
              );
            }()
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
    Station? station;
    for (var s in stations) {
      if (s.id == selectedStation) {
        station = s;
        break;
      }
    }

    AlarmResponse? ownResponse;
    if (alarm.responses.containsKey(relevantLocalPerson.idNumber)) {
      ownResponse = alarm.responses[relevantLocalPerson.idNumber];
    }

    AlarmResponseType? selectedStationOwnResponseType;
    if (ownResponse != null && station != null) {
      if (ownResponse.responses.containsKey(station.idNumber)) {
        selectedStationOwnResponseType = ownResponse.responses[station.idNumber];
      }
    } else if (ownResponse != null && station == null) {
      selectedStationOwnResponseType = AlarmResponseType.notReady;
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0 + kDefaultFontSize * 2),
        child: GestureDetector(
          onLongPress: () {
            if (alarm.responseTimeExpired) {
              errorToast('Die Antwortzeit ist abgelaufen.');
              return;
            }

            setState(() {
              newAnswer = true;
              selectedStation = null;
            });

            resetMapInfoNotifiers();
          },
          child: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.of(Globals.context!).pop();
              },
            ),
            backgroundColor: selectedStationOwnResponseType?.color ?? Colors.white,
            title: const Text('Alarmierung', style: TextStyle(color: Colors.black)),
            actions: [
              // refresh button
              AnimatedRotation(
                duration: alarmDetailsBusy ? const Duration(milliseconds: 5000) : Duration.zero,
                turns: alarmDetailsBusy ? 10 : 0,
                curve: Curves.linear,
                child: IconButton(
                  tooltip: 'Aktualisieren',
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: () {
                    fetchAlarmDetails();
                  },
                ),
              ),
              // share button
              IconButton(
                tooltip: 'Teilen',
                icon: const Icon(Icons.share, color: Colors.black),
                onPressed: () async {
                  String shareString = 'Alarm: ${alarm.type}\n';
                  shareString += 'Stichwort: ${alarm.word}\n';
                  shareString += 'Datum: ${Formats.dateTime(alarm.date)}\n\n';

                  Position? pos = alarm.positionFromAddressIfCoordinates;
                  if (pos != null) {
                    shareString += 'Koordinaten: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}\n';
                  } else {
                    shareString += 'Adresse: ${alarm.address}\n';
                  }

                  shareString += 'Notizen: ${alarm.notes.join('\n')}\n\n';

                  if (data != null) {
                    shareString += 'Einheiten:\n';
                    for (var unit in data!.units) {
                      Station? station;
                      for (var s in data!.stations) {
                        if (s.idNumber == unit.stationId) {
                          station = s;
                          break;
                        }
                      }
                      if (station != null) {
                        shareString += '  - ${unit.unitCallSign(station)}: ${unit.unitDescription}\n';
                      }
                    }
                  }

                  await Share.share(shareString);
                },
              ),
              const SizedBox(width: 10),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kDefaultFontSize * 2),
              child: Column(
                children: [
                  if (ownResponse != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Deine Antwort: ${selectedStationOwnResponseType!.name} (${DateFormat('HH:mm').format(alarm.responses[relevantLocalPerson.idNumber]!.time)})',
                              style: const TextStyle(color: Colors.black, fontSize: kDefaultFontSize),
                            ),
                            if (!alarm.responseTimeExpired) const Text('Klicke hier lang, um deine Antwort zu ändern', style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize)),
                            if (alarm.responseTimeExpired) const Text('Die Antwortzeit ist abgelaufen', style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize)),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!alarm.responseTimeExpired) const Text('Du hast noch nicht geantwortet -', style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize)),
                            if (!alarm.responseTimeExpired) const Text('Klicke hier lang, um deine Antwort zu setzen', style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize)),
                            if (alarm.responseTimeExpired) const Text('Du hast nicht geantwortet -', style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize)),
                            if (alarm.responseTimeExpired) const Text('Die Antwortzeit ist abgelaufen', style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize)),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: tabController,
            tabs: const [
              Tab(text: 'Infos'),
              Tab(text: 'Bereitschaft'),
              Tab(text: 'Antworten'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                /// Informationen:
                /// - Zeit
                /// - Typ + Wort
                /// - Adresse
                /// - Notizen
                /// - Alarmierte Einheiten / Wachen (Darunter deren Antworten)
                /// - Karte mit Position (Umschalten zwischen Karte und Satellit, zeigt Route von Wache bis Einsatzort)
                SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // General information (time, type, word, address, notes)
                      ...genericAlarmInfo(),
                      if (ownResponse != null) const Divider(height: 12),
                      if (ownResponse != null) const SizedBox(height: 4),
                      if (ownResponse != null)
                        Column(
                          children: [
                            if (station != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Icon(Icons.home_outlined),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text('Deine Wachenzusage: ${station.name}, um ${DateFormat('HH:mm').format(ownResponse.time)}')),
                                ],
                              )
                            else
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(Icons.cancel_outlined),
                                  SizedBox(width: 8),
                                  Flexible(child: Text('Du hast dich von dieser Alarmierung abgemeldet')),
                                ],
                              ),
                            if (alarm.units.isNotEmpty) const SizedBox(height: 8),
                            if (alarm.units.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'Deine Notiz',
                                        hintText: 'Deine Notiz',
                                        counter: const SizedBox(),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      keyboardType: TextInputType.text,
                                      maxLines: 1,
                                      maxLength: 200,
                                      controller: noteController,
                                      focusNode: noteFocusNode,
                                      textCapitalization: TextCapitalization.sentences,
                                      expands: false,
                                      readOnly: alarm.responseTimeExpired,
                                      onEditingComplete: () async {
                                        if (alarm.responses.containsKey(relevantLocalPerson.idNumber)) {
                                          if (noteController.text == (alarm.responses[relevantLocalPerson.idNumber]!.note)) return;
                                          try {
                                            noteFocusNode.unfocus();
                                            await AlarmInterface.setResponse(
                                              server: alarm.server,
                                              alarmId: alarm.idNumber,
                                              responseType: selectedStationOwnResponseType!,
                                              stationId: station?.idNumber,
                                              note: noteController.text,
                                            );
                                            successToast('Notiz gespeichert');
                                          } catch (e, s) {
                                            exceptionToast(e, s);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.send_outlined, size: 30),
                                    onPressed: () async {
                                      if (alarm.responses.containsKey(relevantLocalPerson.idNumber)) {
                                        if (noteController.text == (alarm.responses[relevantLocalPerson.idNumber]!.note)) return;
                                        try {
                                          noteFocusNode.unfocus();
                                          await AlarmInterface.setResponse(
                                            server: alarm.server,
                                            alarmId: alarm.idNumber,
                                            responseType: selectedStationOwnResponseType!,
                                            stationId: station?.idNumber,
                                            note: noteController.text,
                                          );
                                          successToast('Notiz gespeichert');
                                        } catch (e, s) {
                                          exceptionToast(e, s);
                                          AlarmInterface.getDetails(alarm).then((value) {
                                            data = value;
                                            noteController.text = alarm.responses[relevantLocalPerson.idNumber]!.note;
                                            if (mounted) setState(() {});
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      // Alarmed units / stations and responding amount of people
                      if (data != null && alarm.units.isNotEmpty) const Divider(height: 20),
                      if (data != null && alarm.units.isNotEmpty) Text('Alarmierte Einheiten:', style: Theme.of(context).textTheme.titleMedium),
                      if (data != null && alarm.units.isNotEmpty)
                        () {
                          List<({Station station, List<Unit> units, List<Person> persons})> stationUnits = [];
                          for (var station in data!.stations) {
                            List<Unit> dispatchedUnits = [];
                            for (var unit in data!.units) {
                              if (unit.stationId == station.idNumber) dispatchedUnits.add(unit);
                            }
                            units.sort((a, b) => a.unitCallSign(station).compareTo(b.unitCallSign(station)));

                            List<Person> persons = [];
                            for (var person in data!.persons) {
                              // continue if not answered or answered for another station or notReady or onCall
                              if (!alarm.responses.containsKey(person.idNumber)) continue;
                              var response = alarm.responses[person.idNumber]!;
                              if (response.responses.containsKey(station.idNumber)) {
                                if (response.responses[station.idNumber] == AlarmResponseType.notReady ||
                                    response.responses[station.idNumber] == AlarmResponseType.onCall ||
                                    response.responses[station.idNumber] == AlarmResponseType.notSet) {
                                  continue;
                                }
                              } else {
                                continue;
                              }

                              persons.add(person);
                            }

                            stationUnits.add((station: station, units: dispatchedUnits, persons: persons));
                          }

                          stationUnits.sort((a, b) => a.station.name.compareTo(b.station.name));

                          return Column(
                            children: [
                              for (var element in stationUnits)
                                Card(
                                  color: Theme.of(context).cardColor,
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.all(8),
                                  elevation: 5,
                                  child: Column(
                                    children: [
                                      Text('${element.station.name} (${element.station.prefix} ${element.station.area} ${element.station.stationNumber})',
                                          style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.groups_outlined),
                                          const SizedBox(width: 5),
                                          () {
                                            int zf = 0;
                                            int gf = 0;
                                            int agt = 0;
                                            int ma = 0;
                                            int other = 0;

                                            for (var person in element.persons) {
                                              if (person.hasQualification("zf", alarm.date)) {
                                                zf++;
                                              } else if (person.hasQualification("gf", alarm.date)) {
                                                gf++;
                                              } else {
                                                other++;
                                              }
                                              if (person.hasQualification("agt", alarm.date)) agt++;
                                              if (person.hasQualification("ma", alarm.date)) ma++;
                                            }

                                            return Text('$zf / $gf / $other / ${element.persons.length} (AGT: $agt, Ma: $ma)');
                                          }(),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      for (var unit in element.units)
                                        Card(
                                          color: Theme.of(context).focusColor,
                                          clipBehavior: Clip.antiAliasWithSaveLayer,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          margin: const EdgeInsets.all(8),
                                          elevation: 5,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                () {
                                                  int zf = 0;
                                                  int gf = 0;
                                                  int other = unit.capacity;
                                                  int total = unit.capacity;

                                                  for (var position in unit.positions) {
                                                    if (position == UnitPosition.zf) {
                                                      zf++;
                                                      other--;
                                                    }
                                                    if (position == UnitPosition.gf) {
                                                      gf++;
                                                      other--;
                                                    }
                                                  }

                                                  if (gf == 0 && zf == 0 && unit.positions.contains(UnitPosition.atf)) {
                                                    other--;
                                                    gf++;
                                                  }

                                                  String text = '$gf / $other / $total';
                                                  if (zf > 0) text = '$zf / $text';

                                                  return Row(
                                                    children: [
                                                      Text("${unit.unitCallSign(element.station)} ($text)"),
                                                    ],
                                                  );
                                                }(),
                                                const SizedBox(height: 5),
                                                Text(unit.unitDescription),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }(),
                      // External map app controls
                      if (data != null && alarm.units.isNotEmpty) const Divider(height: 20),
                      if (station != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (station.position != null)
                              ElevatedButton(
                                onPressed: () async {
                                  var maps = await MapLauncher.installedMaps;
                                  if (maps.isNotEmpty) {
                                    await MapLauncher.showDirections(
                                      mapType: MapType.google,
                                      destination: Coords(station!.position!.latitude, station.position!.longitude),
                                      destinationTitle: 'Wache ${station.name}',
                                      origin: () {
                                        if (Globals.lastPosition != null) {
                                          return Coords(Globals.lastPosition!.latitude, Globals.lastPosition!.longitude);
                                        }
                                      }(),
                                    );
                                  } else {
                                    errorToast('Keine Karten-App gefunden');
                                  }
                                },
                                child: Column(
                                  children: [
                                    const Row(
                                      children: <Widget>[
                                        Text('Zur Wache', style: TextStyle(color: Colors.blue)),
                                        SizedBox(width: 5),
                                        Icon(Icons.home, size: 15, color: Colors.blue),
                                      ],
                                    ),
                                    if (station.position != null && Globals.lastPosition != null)
                                      Row(
                                        children: [
                                          Text(
                                            "> ${Formats.distanceBetween(Globals.lastPosition!, station.position!)}",
                                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                                          ),
                                          const SizedBox(width: 5),
                                          const Icon(Icons.route, size: 15, color: Colors.blue),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                var maps = await MapLauncher.installedMaps;
                                if (maps.isNotEmpty) {
                                  await MapLauncher.showDirections(
                                    mapType: MapType.google,
                                    destination: Coords(alarmPosition!.latitude, alarmPosition!.longitude),
                                    destinationTitle: 'Einsatzort',
                                    origin: () {
                                      if (Globals.lastPosition != null) {
                                        return Coords(Globals.lastPosition!.latitude, Globals.lastPosition!.longitude);
                                      }
                                    }(),
                                  );
                                } else {
                                  errorToast('Keine Karten-App gefunden');
                                }
                              },
                              child: Column(
                                children: [
                                  const Row(
                                    children: <Widget>[
                                      Text('Zum Einsatzort', style: TextStyle(color: Colors.red)),
                                      SizedBox(width: 5),
                                      Icon(Icons.local_fire_department, size: 15, color: Colors.red),
                                    ],
                                  ),
                                  if (alarmPosition != null && Globals.lastPosition != null)
                                    Row(
                                      children: [
                                        Text(
                                          "> ${Formats.distanceBetween(Globals.lastPosition!, Formats.latLngToPosition(alarmPosition!))}",
                                          style: const TextStyle(fontSize: 12, color: Colors.red),
                                        ),
                                        const SizedBox(width: 5),
                                        const Icon(Icons.route, size: 15, color: Colors.red),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // Map of the alarm
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height / 4,
                              child: alarmPosition != null
                                  ? MapPage(
                                      controller: alarmMapController,
                                      initialPosition: alarmPosition!,
                                      positionsNotifier: informationNotifier,
                                    )
                                  : const Card(
                                      color: Colors.grey,
                                      child: Center(
                                        child: Text('Karte wird geladen....', style: TextStyle(color: Colors.black)),
                                      ),
                                    ),
                            ),
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
                                  if (alarmPosition == null) return;
                                  Navigator.of(context)
                                      .push(
                                    MaterialPageRoute(
                                      builder: (context) => Scaffold(
                                        appBar: AppBar(
                                          title: const Text('Karte'),
                                          actions: [
                                            if (Globals.lastPosition != null)
                                              IconButton(
                                                icon: const Icon(Icons.person, color: Colors.green),
                                                onPressed: () {
                                                  alarmMapController.smoothMove(Formats.positionToLatLng(Globals.lastPosition!), 15.5);
                                                },
                                              ),
                                            if (station != null && station.position != null)
                                              IconButton(
                                                icon: const Icon(Icons.home, color: Colors.blue),
                                                onPressed: () {
                                                  alarmMapController.smoothMove(Formats.positionToLatLng(station!.position!), 15.5);
                                                },
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.local_fire_department, color: Colors.red),
                                              onPressed: () {
                                                alarmMapController.smoothMove(alarmPosition!, 15.5);
                                              },
                                            ),
                                          ],
                                        ),
                                        body: MapPage(
                                          controller: alarmMapController,
                                          initialPosition: alarmPosition!,
                                          positionsNotifier: informationNotifier,
                                        ),
                                      ),
                                    ),
                                  )
                                      .then((_) {
                                    alarmMapController.smoothMove(alarmPosition!, 15.5);
                                  });
                                },
                                child: Container(
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                /// Bereitschaft:
                /// - Nach wie viel Zeit welche Funktion wie viele hat
                SafeArea(
                  child: () {
                    if (data == null) return const Center(child: CircularProgressIndicator());

                    if (station == null) {
                      return const Center(child: Text('Keine Wache ausgewählt'));
                    }

                    List<MapEntry<Person, AlarmResponse>> responsesForSelectedStation = [];
                    for (var person in data!.persons) {
                      if (alarm.responses.containsKey(person.idNumber)) {
                        if (alarm.responses[person.idNumber]!.responses.containsKey(station.idNumber)) {
                          responsesForSelectedStation.add(MapEntry(person, alarm.responses[person.idNumber]!));
                        } else {
                          responsesForSelectedStation.add(MapEntry(person, AlarmResponse(time: alarm.date, responses: {}, note: '')));
                        }
                      } else {
                        responsesForSelectedStation.add(MapEntry(person, AlarmResponse(time: alarm.date, responses: {}, note: '')));
                      }
                    }

                    Map<AlarmResponseType, Map<String, int>> responseTypes = {};
                    Map<AlarmResponseType, int> responseTypesTotal = {};
                    for (var type in AlarmResponseType.values) {
                      responseTypes[type] = {};
                      responseTypesTotal[type] = 0;
                    }

                    for (var entry in responsesForSelectedStation) {
                      var person = entry.key;
                      var response = entry.value.responses[station.idNumber];
                      if (response == null) continue;

                      var activeQualifications = person.activeQualifications(alarm.date);
                      for (var qualification in activeQualifications) {
                        String type = qualification.type;

                        for (var key in responseTypes.keys) {
                          if (!responseTypes[key]!.containsKey(type)) {
                            responseTypes[key]![type] = 0;
                          }
                        }

                        if (response.timeAmount >= 0) {
                          for (var key in responseTypes.keys) {
                            if (key.timeAmount >= response.timeAmount) {
                              responseTypes[key]![type] = responseTypes[key]![type]! + 1;
                            }
                          }
                        } else {
                          responseTypes[response]![type] = responseTypes[response]![type]! + 1;
                        }
                      }

                      if (response.timeAmount >= 0) {
                        for (var key in responseTypes.keys) {
                          if (key.timeAmount >= response.timeAmount) {
                            responseTypesTotal[key] = responseTypesTotal[key]! + 1;
                          }
                        }
                      } else {
                        responseTypesTotal[response] = responseTypesTotal[response]! + 1;
                      }
                    }

                    List<Map<String, int>> responseTypesList = [];
                    for (var type in AlarmResponseType.values) {
                      responseTypesList.add(responseTypes[type]!);
                    }

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              children: [
                                for (var type in AlarmResponseType.values)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    color: type.color,
                                    child: Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            for (var entry in responseTypesList[type.index].entries)
                                              if (entry.value == 0)
                                                const SizedBox()
                                              else
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${entry.key}:',
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        height: 1.3,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      ' ${entry.value.toString().padLeft(2, '  ')}',
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Gesamt:',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    height: 1.3,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  ' ${responseTypesTotal[type].toString().padLeft(2, '  ')}',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Column(
                                          children: [
                                            Text(
                                              type.name,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (type.timeAmount >= 0)
                                              Text(
                                                'bis ${DateFormat('HH:mm').format(alarm.date.add(Duration(minutes: type.timeAmount)))}',
                                                style: const TextStyle(color: Colors.black),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            )),
                      ),
                    );
                  }(),
                ),

                /// Antworten:
                /// - Liste der Personen, die für die gleiche Wache geantwortet haben wie der lokale Nutzer
                /// - Informationen zu den Qualifikationen der Personen (AGT, TF / GF / ZF, Ma)
                /// - Anzeige der Antworten und ca. Zeit (Farblich markiert)
                /// - Karte mit live Position aller Personen, die positiv geantwortet haben
                SafeArea(
                  child: () {
                    if (data == null) return const Center(child: CircularProgressIndicator());

                    if (station == null) {
                      return const Center(child: Text('Keine Wache ausgewählt'));
                    }

                    List<MapEntry<Person, AlarmResponse>> responsesForSelectedStation = [];
                    for (var person in data!.persons) {
                      if (alarm.responses.containsKey(person.idNumber)) {
                        if (alarm.responses[person.idNumber]!.responses.containsKey(station.idNumber)) {
                          responsesForSelectedStation.add(MapEntry(person, alarm.responses[person.idNumber]!));
                        }
                      }
                    }

                    // sort by response.index, if same by name
                    responsesForSelectedStation.sort((a, b) {
                      var aResponse = a.value.responses[station!.idNumber]!;
                      var bResponse = b.value.responses[station.idNumber]!;

                      if (aResponse.index == bResponse.index) {
                        return a.key.fullName.compareTo(b.key.fullName);
                      }
                      return aResponse.index.compareTo(bResponse.index);
                    });

                    return ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (var entry in responsesForSelectedStation)
                          () {
                            var activeQualifications = entry.key.activeQualifications(alarm.date);
                            return Card(
                              color: entry.value.responses[station!.idNumber]!.color,
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 5,
                              child: ListTile(
                                title: Text(entry.key.fullName, style: const TextStyle(color: Colors.black)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.value.responses[station.idNumber]!.name, style: const TextStyle(color: Colors.black)),
                                    if (entry.value.responses[station.idNumber]!.timeAmount >= 0)
                                      Text(
                                        'Ankunft bis ${DateFormat('HH:mm').format(entry.value.time.add(Duration(minutes: entry.value.responses[station.idNumber]!.timeAmount)))}',
                                        style: const TextStyle(color: Colors.black),
                                      ),
                                    if (activeQualifications.isNotEmpty) const SizedBox(height: 5),
                                    if (activeQualifications.isNotEmpty)
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              activeQualifications.map((e) => e.type).join(',  '),
                                              style: const TextStyle(color: Colors.black),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (entry.value.note.isNotEmpty) const SizedBox(height: 5),
                                    if (entry.value.note.isNotEmpty) Text(entry.value.note, style: const TextStyle(color: Colors.black)),
                                  ],
                                ),
                                trailing: Text(DateFormat('HH:mm').format(entry.value.time), style: const TextStyle(color: Colors.black)),
                              ),
                            );
                          }(),
                        const SizedBox(height: 8),
                      ],
                    );
                  }(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void resetMapInfoNotifiers() {
    if (!mounted) return;
    informationNotifier.value = [];

    if (alarmPosition != null) {
      informationNotifier.value.add(MapPos(
        id: 'alarm',
        position: alarmPosition!,
        name: 'Einsatzort',
        widget: const PulseIcon(
          pulseColor: Colors.red,
          icon: Icons.local_fire_department,
          pulseCount: 2,
        ),
      ));
    }

    if (Globals.lastPosition != null) {
      informationNotifier.value.add(MapPos(
        id: 'self',
        position: Formats.positionToLatLng(Globals.lastPosition!),
        name: 'Du',
        widget: const PulseIcon(
          pulseColor: Colors.green,
          icon: Icons.person,
          pulseCount: 2,
        ),
      ));
    }

    if (selectedStation != null) {
      Station? station;
      for (var s in stations) {
        if (s.id == selectedStation) {
          station = s;
          break;
        }
      }
      if (station != null && station.position != null) {
        informationNotifier.value.add(MapPos(
          id: 'station',
          position: Formats.positionToLatLng(station.position!),
          name: 'Wache',
          widget: const PulseIcon(
            pulseColor: Colors.blue,
            icon: Icons.home,
            pulseCount: 2,
          ),
        ));
      }
    }
  }

  Future<void> fetchAlarmDetails() async {
    if (alarmDetailsBusy) return;
    alarmDetailsBusy = true;
    if (mounted) setState(() {});
    try {
      data = await AlarmInterface.getDetails(alarm);
      alarm = data!.alarm;
      resetMapInfoNotifiers();
    } catch (e, s) {
      exceptionToast(e, s);
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      alarmDetailsBusy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.alarm && info.ids.contains(widget.alarm.id)) {
      Set<int> oldResponses = alarm.responses.keys.toSet();
      var a = await Globals.db.alarmDao.getById(widget.alarm.id);
      if (!mounted) return;
      if (a == null) {
        Navigator.of(Globals.context!).pop();
      } else {
        alarm = a;
        setState(() {});

        Set<int> newResponses = alarm.responses.keys.toSet();
        if (oldResponses.length != newResponses.length) {
          fetchAlarmDetails();
        }
      }
    } else if (info.type == UpdateType.ui) {
      if (info.ids.contains("2") && Globals.lastPosition != null) {
        // update pos in both maps
        bool foundInInfo = false;
        for (var pos in informationNotifier.value) {
          if (pos.id == 'self') {
            pos.position = Formats.positionToLatLng(Globals.lastPosition!);
            foundInInfo = true;
          }
        }
        if (!foundInInfo) {
          informationNotifier.value.add(MapPos(
            id: 'self',
            position: Formats.positionToLatLng(Globals.lastPosition!),
            name: 'Du',
            widget: const PulseIcon(
              pulseColor: Colors.green,
              icon: Icons.person,
              pulseCount: 2,
            ),
          ));
        }
      }

      informationNotifier.notifyListeners();

      if (info.ids.contains("0")) {
        AlarmInterface.getDetails(alarm).then((value) {
          data = value;
          if (!mounted) return;
          setState(() {
            loading = false;
          });
        }).catchError((e, s) {
          if (!mounted) return;
          setState(() {
            loading = false;
          });
        });
      }
    }
  }

  List<Widget> genericAlarmInfo() {
    return [
      InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: Formats.dateTime(alarm.date)));
          successToast('Uhrzeit kopiert');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(Icons.access_time),
              const SizedBox(width: 8),
              Text(Formats.dateTime(alarm.date)),
              const SizedBox(width: 15),
              () {
                DateTime now = DateTime.now();
                Duration difference = now.difference(alarm.date);

                if (difference.inMinutes < 1) {
                  return const Text('(Jetzt)');
                } else if (difference.inMinutes < 60) {
                  return Text('(vor ${difference.inMinutes} min)');
                } else if (difference.inHours < 3) {
                  return Text('(vor ${difference.inHours} h, ${difference.inMinutes % 60} min)');
                } else if (difference.inHours < 24) {
                  return Text('(vor ${difference.inHours} h)');
                } else {
                  return Text('(vor ${difference.inDays} d)');
                }
              }(),
            ],
          ),
        ),
      ),
      InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: '${alarm.type} - ${alarm.word}'));
          successToast('Typ und Stichwort kopiert');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(Icons.info_outlined),
              const SizedBox(width: 8),
              Flexible(child: Text('${alarm.type} - ${alarm.word}')),
            ],
          ),
        ),
      ),
      InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: alarm.address));
          successToast('Adresse kopiert');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  () {
                    var pos = alarm.positionFromAddressIfCoordinates;
                    if (pos != null) {
                      return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
                    } else {
                      return alarm.address;
                    }
                  }(),
                ),
              ),
            ],
          ),
        ),
      ),
      if (alarm.notes.isNotEmpty) const Divider(height: 12),
      if (alarm.notes.isNotEmpty)
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: alarm.notes.join('\n')));
            successToast('Notizen kopiert');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined),
                const SizedBox(width: 8),
                Flexible(child: Text(alarm.notes.join('\n'))),
              ],
            ),
          ),
        ),
    ];
  }
}

enum AlarmResponseType {
  onStation(0),
  under5(5),
  under10(10),
  under15(15),
  onCall(-1),
  notReady(-2),
  notSet(-3);

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
      case AlarmResponseType.notSet:
        return Colors.white;
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
      case AlarmResponseType.notSet:
        return 'Nicht gesetzt';
    }
  }
}
