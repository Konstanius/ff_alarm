import 'dart:async';

import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/utils/format.dart';
import 'package:ff_alarm/ui/utils/no_data.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key, required this.badge, required this.setActionWidgets});

  final ValueNotifier<int> badge;
  final void Function(List<Widget>) setActionWidgets;

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class AlarmsFilter {
  DateTime? date;
  bool? testsMode;
  AlarmResponseType? responseType;
  bool responseNotSet = false;
  String? search;
  String? station;

  bool get noFilters => date == null && testsMode == null && responseType == null && search == null && !responseNotSet && station == null;

  bool filter(Alarm alarm) {
    if (date != null && (alarm.date.year != date!.year || alarm.date.month != date!.month || alarm.date.day != date!.day)) return false;
    if (testsMode != null && alarm.type.startsWith('Test') != testsMode) return false;

    AlarmResponse? ownResponse = alarm.ownResponse;
    var info = ownResponse?.getResponseInfo();

    if (responseNotSet && ownResponse != null && ownResponse.getResponseInfo().responseType != AlarmResponseType.notSet) return false;
    if (responseType != null && info?.responseType != responseType) return false;
    if (search != null &&
        !alarm.word.toLowerCase().contains(search!) &&
        !alarm.address.toLowerCase().contains(search!) &&
        !alarm.notes.any((element) => element.toLowerCase().contains(search!)) &&
        !alarm.type.toLowerCase().contains(search!)) return false;
    if (station != null && station != "${alarm.server} ${info?.stationId}") return false;
    return true;
  }
}

class _AlarmsScreenState extends State<AlarmsScreen> with AutomaticKeepAliveClientMixin, Updates, SingleTickerProviderStateMixin, DateTimeChangeListener {
  @override
  bool get wantKeepAlive => true;

  List<Alarm> alarms = [];
  bool loading = true;

  AlarmsFilter filter = AlarmsFilter();
  TextEditingController searchController = TextEditingController();

  late AnimationController controller;

  @override
  void onDateTimeChangeExecution() {
    if (!mounted) return;
    setState(() {});
    resetBadge();
  }

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.alarm, UpdateType.ui});

    DateTime now = DateTime.now();
    DateTime minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    setupDateTimeChangeListener(const Duration(minutes: 1), minute);

    controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    controller.repeat(reverse: true);

    widget.setActionWidgets([
      IconButton(
        icon: Icon(Icons.filter_alt_outlined, color: filter.noFilters ? null : Colors.blue),
        onPressed: () async {
          if (opening) return;
          opening = true;
          searchController.text = filter.search ?? '';

          var stations = await Station.getAll();

          showDialog(
            context: Globals.context!,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter sbSetState) {
                  return AlertDialog(
                    title: const Text('Alarmierungen filtern'),
                    content: LimitedBox(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Datum'),
                                TextButton(
                                  onPressed: () async {
                                    DateTime lowest = DateTime.now();
                                    for (var alarm in alarms) {
                                      if (alarm.date.isBefore(lowest)) lowest = alarm.date;
                                    }
                                    DateTime? date = await showDatePicker(
                                      context: context,
                                      initialDate: filter.date ?? DateTime.now(),
                                      firstDate: lowest,
                                      lastDate: DateTime.now(),
                                    );
                                    if (date == null) return;
                                    sbSetState(() {
                                      filter.date = date;
                                    });
                                    setState(() {});
                                  },
                                  child: Text(filter.date == null ? 'Alle' : Formats.date(filter.date!)),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tests'),
                                DropdownButton<bool>(
                                  value: filter.testsMode,
                                  onChanged: (bool? value) {
                                    sbSetState(() {
                                      filter.testsMode = value;
                                    });
                                    setState(() {});
                                  },
                                  items: const [
                                    DropdownMenuItem<bool>(
                                      value: null,
                                      child: Text('Zeigen'),
                                    ),
                                    DropdownMenuItem<bool>(
                                      value: true,
                                      child: Text('Nur Tests'),
                                    ),
                                    DropdownMenuItem<bool>(
                                      value: false,
                                      child: Text('Verstecken'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Antwort'),
                                DropdownButton(
                                  value: filter.responseType ?? (filter.responseNotSet ? -1 : null),
                                  onChanged: (dynamic value) {
                                    sbSetState(() {
                                      filter.responseNotSet = false;
                                      filter.responseType = value;
                                    });
                                    setState(() {});
                                  },
                                  items: [
                                    const DropdownMenuItem<dynamic>(
                                      value: null,
                                      child: Text('Alle'),
                                    ),
                                    for (var type in AlarmResponseType.values)
                                      DropdownMenuItem<dynamic>(
                                        value: type,
                                        child: Text(type.name),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Wache'),
                                DropdownButton<String?>(
                                  value: filter.station,
                                  onChanged: (String? value) {
                                    sbSetState(() {
                                      filter.station = value;
                                    });
                                    setState(() {});
                                  },
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Alle'),
                                    ),
                                    for (var station in stations)
                                      DropdownMenuItem<String>(
                                        value: station.id,
                                        child: Text(station.name),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: searchController,
                                    onChanged: (String value) {
                                      if (value.trim().isEmpty) {
                                        sbSetState(() {
                                          filter.search = null;
                                        });
                                        setState(() {});
                                        return;
                                      }
                                      sbSetState(() {
                                        filter.search = value.toLowerCase();
                                      });
                                      setState(() {});
                                    },
                                    decoration: const InputDecoration(hintText: 'Suche'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      if (!filter.noFilters)
                        TextButton(
                          onPressed: () {
                            sbSetState(() {
                              filter = AlarmsFilter();
                              searchController.clear();
                            });
                            setState(() {});
                          },
                          child: const Text('Zurücksetzen'),
                        ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Schließen'),
                      ),
                    ],
                  );
                },
              );
            },
          );
          opening = false;
        },
      ),
    ]);

    StreamSubscription subscription = Alarm.getAllStreamed().listen((List<Alarm> value) {
      if (!mounted) return;
      loading = false;
      alarms.addAll(value);
      alarms.sort((a, b) => b.date.compareTo(a.date));
      setState(() {});
      resetBadge();
    });

    subscription.onDone(() {
      subscription.cancel();
      if (!mounted || !loading) return;
      loading = false;
      setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  bool opening = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    List<Alarm> alarmsList = filter.noFilters ? alarms : alarms.where((element) => filter.filter(element)).toList();

    Widget bodyWidget;
    if (loading) {
      bodyWidget = const SizedBox();
    } else if (alarms.isEmpty) {
      bodyWidget = const NoDataWidget(text: 'Keine Alarmierungen vorhanden');
    } else if (alarmsList.isEmpty) {
      bodyWidget = NoDataWidget(
        text: 'Keine Alarmierungen gefunden',
        button: ElevatedButton(
          onPressed: () {
            filter = AlarmsFilter();
            searchController.clear();
            setState(() {});
          },
          child: const Text('Filter zurücksetzen'),
        ),
      );
    } else {
      bodyWidget = ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: alarmsList.length + 1,
        itemBuilder: (context, i) {
          if (i == alarmsList.length) return const SizedBox(height: kBottomNavigationBarHeight);

          Alarm alarm = alarmsList[i];
          bool dateDivider = i == 0 || alarm.date.day != alarmsList[i - 1].date.day || alarm.date.month != alarmsList[i - 1].date.month || alarm.date.year != alarmsList[i - 1].date.year;

          AlarmResponse? ownResponse = alarm.ownResponse;

          return Column(
            children: <Widget>[
              if (dateDivider) SettingsDivider(text: DateFormat('EEEE, dd.MM.yyyy').format(alarm.date)),
              () {
                var listTile = ListTile(
                  title: Text("${alarm.type} - ${alarm.word}"),
                  subtitle: Text(() {
                    Position? pos = alarm.positionFromAddressIfCoordinates;
                    if (pos == null) return alarm.address;
                    return "${pos.latitude.toStringAsFixed(5)} ° N,   ${pos.longitude.toStringAsFixed(5)} ° E";
                  }()),
                  trailing: Text("${DateFormat('HH:mm').format(alarm.date)} Uhr"),
                  onTap: () {
                    Globals.router.push('/alarm', extra: alarm);
                  },
                );

                return Stack(
                  children: [
                    if (ownResponse?.getResponseInfo().responseType != AlarmResponseType.notReady && !alarm.responseTimeExpired)
                      FadeTransition(
                        opacity: controller,
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          elevation: 10,
                          color: Colors.red.withOpacity(0.4),
                          surfaceTintColor: Colors.transparent,
                          child: listTile,
                        ),
                      )
                    else
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        elevation: 10,
                        color: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                if (ownResponse != null && ownResponse.getResponseInfo().responseType != AlarmResponseType.notSet) ownResponse.getResponseInfo().responseType.color,
                              ],
                              stops: [
                                0.4,
                                if (ownResponse != null && ownResponse.getResponseInfo().responseType != AlarmResponseType.notSet) 1.0,
                              ],
                            ),
                          ),
                          child: listTile,
                        ),
                      ),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      elevation: 10,
                      color: Colors.transparent,
                      child: listTile,
                    ),
                  ],
                );
              }(),
            ],
          );
        },
      );
    }

    return Scaffold(body: bodyWidget);
  }

  void resetBadge() {
    int badge = 0;
    for (var alarm in alarms) {
      if (alarm.ownResponse?.getResponseInfo().responseType == AlarmResponseType.notSet && !alarm.responseTimeExpired) {
        badge++;
      }
    }
    widget.badge.value = badge;
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.alarm) {
      DateTime lowest = DateTime(2000);
      for (var alarm in this.alarms) {
        if (alarm.date.isBefore(lowest)) lowest = alarm.date;
      }

      var alarms = <Alarm>[];
      var futures = <Future<Alarm?>>[];
      Set<String> ids = {...info.ids};
      for (String id in info.ids) {
        futures.add(Globals.db.alarmDao.getById(id));
      }

      var values = await Future.wait(futures);
      for (var value in values) {
        if (value == null) continue;
        if (value.date.isBefore(lowest)) continue;
        alarms.add(value);
        ids.remove(value.id);
      }

      for (var alarm in alarms) {
        var index = this.alarms.indexWhere((element) => element.id == alarm.id);
        if (index != -1) {
          this.alarms[index] = alarm;
        } else {
          this.alarms.add(alarm);
        }
      }

      this.alarms.removeWhere((element) => ids.contains(element.id));

      this.alarms.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {});

      resetBadge();
    } else if (info.type == UpdateType.ui && info.ids.contains("3")) {
      alarms.clear();
      StreamSubscription subscription = Alarm.getAllStreamed().listen((List<Alarm> value) {
        if (!mounted) return;
        loading = false;
        alarms.addAll(value);
        alarms.sort((a, b) => b.date.compareTo(a.date));
        setState(() {});
        resetBadge();
      });

      subscription.onDone(() {
        subscription.cancel();
        if (!mounted || !loading) return;
        loading = false;
        setState(() {});
      });
    }
  }
}
