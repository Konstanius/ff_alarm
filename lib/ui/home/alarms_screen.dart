import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/popups/alarm_info.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key, required this.badge});

  final ValueNotifier<int> badge;

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class AlarmsFilter {
  DateTime? date;
  bool? testsMode;
  AlarmResponseType? responseType;
  bool responseNotSet = false;
  String? search;

  AlarmsFilter({this.date, this.testsMode, this.responseType});

  bool get noFilters => date == null && testsMode == null && responseType == null && search == null && !responseNotSet;

  bool filter(Alarm alarm) {
    if (date != null && (alarm.date.year != date!.year || alarm.date.month != date!.month || alarm.date.day != date!.day)) return false;
    if (testsMode != null && alarm.type.startsWith('Test') != testsMode) return false;
    if (responseNotSet && alarm.responses.containsKey(Globals.person!.id)) return false;
    if (responseType != null && alarm.responses[Globals.person!.id]?.type != responseType) return false;
    if (search != null &&
        !alarm.word.toLowerCase().contains(search!) &&
        !alarm.address.toLowerCase().contains(search!) &&
        !alarm.notes.any((element) => element.toLowerCase().contains(search!)) &&
        !alarm.type.toLowerCase().contains(search!)) return false;
    return true;
  }
}

class _AlarmsScreenState extends State<AlarmsScreen> with AutomaticKeepAliveClientMixin, Updates {
  @override
  bool get wantKeepAlive => true;

  List<Alarm> alarms = [];

  AlarmsFilter filter = AlarmsFilter();
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.alarm, UpdateType.ui});

    if (!Globals.loggedIn) return;

    Alarm.getAllStreamed().listen((List<Alarm> value) {
      if (!mounted) return;
      alarms.addAll(value);
      alarms.sort((a, b) => b.date.compareTo(a.date));
      setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    List<Alarm> alarmsList = filter.noFilters ? alarms : alarms.where((element) => filter.filter(element)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmierungen'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () {
              searchController.text = filter.search ?? '';
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return StatefulBuilder(
                    builder: (BuildContext context, StateSetter sbSetState) {
                      return AlertDialog(
                        title: const Text('Filter'),
                        content: LimitedBox(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                          child: SingleChildScrollView(
                            child: ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Datum'),
                                    TextButton(
                                      onPressed: () async {
                                        DateTime? date = await showDatePicker(
                                          context: context,
                                          initialDate: filter.date ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (date == null) return;
                                        sbSetState(() {
                                          filter.date = date;
                                        });
                                        setState(() {});
                                      },
                                      child: Text(filter.date == null ? 'Alle' : DateFormat('dd.MM.yyyy').format(filter.date!)),
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
                                        if (value == -1) {
                                          sbSetState(() {
                                            filter.responseType = null;
                                            filter.responseNotSet = true;
                                          });
                                          setState(() {});
                                          return;
                                        }
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
                                        const DropdownMenuItem<dynamic>(
                                          value: -1,
                                          child: Text('Keine'),
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
                        actions: <Widget>[
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
            },
          ),
        ],
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
          for (int i = 0; i < alarmsList.length; i++)
            () {
              Alarm alarm = alarmsList[i];
              bool dateDivider = i == 0 || alarm.date.day != alarmsList[i - 1].date.day || alarm.date.month != alarmsList[i - 1].date.month || alarm.date.year != alarmsList[i - 1].date.year;
              return Column(
                children: <Widget>[
                  if (dateDivider) ...[
                    const SizedBox(height: 8),
                    Text(DateFormat('dd.MM.yyyy').format(alarm.date), style: const TextStyle(fontSize: 20)),
                    const Divider(),
                  ],
                  Card(
                    color: (){
                      var response = alarm.responses[Globals.person!.id];
                      if (response == null) return Colors.transparent;
                      return response.type.color.withOpacity(0.5);
                    }(),
                    child: ListTile(
                      title: Text(alarm.word),
                      subtitle: Text(alarm.address),
                      trailing: Text(DateFormat('HH:mm').format(alarm.date)),
                      onTap: () {
                        Globals.router.go('/alarm', extra: alarm);
                      },
                    ),
                  ),
                ],
              );
            }(),
        ],
      ),
    );
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
      Set<int> ids = {...info.ids};
      for (int id in info.ids) {
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
    } else if (info.type == UpdateType.ui && info.ids.contains(3)) {
      alarms.clear();
      Alarm.getBatched(limit: 25).then((List<Alarm> value) {
        if (!mounted) return;
        value.sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          alarms = value;
        });
      });
    }
  }
}
