import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/settings/lifecycle.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/format.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:permission_handler/permission_handler.dart';

/// Optionen:
/// - feste Einstellung (überschreibt alle anderen Einstellungen)
/// - Kalender
/// - Schichtplan
/// - Geofencing
class SettingsNotificationData {
  String stationId;
  String get server => stationId.split(' ')[0];
  int get stationIdNumber => int.parse(stationId.split(' ')[1]);

  /// 0 = off, 1 = none, 2 = always
  int manualOverride;

  /// List of DateTime to DateTime when it is definitely disabled
  List<({DateTime start, DateTime end})> calendar = [];

  /// EITHER Schichtplan OR Geofencing is enabled, not both
  /// 0 = none, 1 = shiftPlan active, 2 = shiftPlan inactive, 3 = geofencing
  int enabledMode;

  /// List of day int, millisecond to millisecond when it is disabled
  List<({int day, int start, int end})> shiftPlan;

  /// List of LatLng to Radius in meters when it is enabled
  List<({LatLng position, int radius})> geofencing;

  SettingsNotificationData({
    required this.stationId,
    required this.manualOverride,
    required this.calendar,
    required this.enabledMode,
    required this.shiftPlan,
    required this.geofencing,
  });

  factory SettingsNotificationData.make({
    required String stationId,
    int? manualOverride,
    List<({DateTime start, DateTime end})>? calendar,
    int? enabledMode,
    List<({int day, int start, int end})>? shiftPlan,
    List<({LatLng position, int radius})>? geofencing,
  }) {
    return SettingsNotificationData(
      stationId: stationId,
      manualOverride: manualOverride ?? 1,
      calendar: calendar ?? [],
      enabledMode: enabledMode ?? 0,
      shiftPlan: shiftPlan ?? [],
      geofencing: geofencing ?? [],
    );
  }

  static Future<bool> shouldNotifyForAlarmRegardless(Alarm alarm) async {
    try {
      Set<String> stations;
      if (alarm.units.isNotEmpty) {
        // TODO get the current LatLng
        var allUnits = await Unit.getAll(filter: (unit) => alarm.unitProperIds.contains(unit.id));
        var filteredUnits = [];
        var personId = Globals.localPersonForServer(alarm.server);
        var person = Globals.localPersons[personId];
        if (person != null) {
          filteredUnits = allUnits.where((unit) => person.allowedUnitProperIds.contains(unit.id)).toList();
        } else {
          filteredUnits = allUnits;
        }

        stations = {...filteredUnits.map((e) => e.stationProperId)};
        if (stations.isEmpty) throw "No stations found for alarm";
      } else {
        var allStations = await Station.getAll();
        stations = allStations.map((e) => e.id).toSet();
      }

      Map<String, SettingsNotificationData> settings = {};
      if (stations.length == 1) {
        settings[stations.first] = loadForStation(stations.first);
      } else {
        var all = getAll();
        for (var station in stations) {
          if (all.containsKey(station)) {
            settings[station] = all[station]!;
          } else {
            settings[station] = SettingsNotificationData.make(stationId: station);
          }
        }
      }

      LatLng? lastPosition;
      if (Globals.lastPosition != null) {
        lastPosition = Formats.positionToLatLng(Globals.lastPosition!);
      }
      for (var data in settings.values) {
        if (data.shouldNotify(lastPosition)) return true;
      }

      return false;
    } catch (e, s) {
      Logger.error("Error in shouldNotifyForAlarmRegardless: $e\n$s");
      return true;
    }
  }

  bool shouldNotify(LatLng? currentPosition) {
    // manualOverride = 0 means everything is disabled
    if (manualOverride == 0) return false;
    // manualOverride = 2 means everything is enabled
    if (manualOverride == 2) return true;

    DateTime now = DateTime.now();
    // if the calendar is not empty, check if we are in a disabled time
    if (calendar.isNotEmpty) {
      for (var item in calendar) {
        if (now.isAfter(item.start) && now.isBefore(item.end)) return false;
      }
    }

    if (enabledMode == 0) return true;

    // if shiftPlan is not empty and enabledMode is 1 or 2
    if ((enabledMode == 1 || enabledMode == 2)) {
      int day = now.weekday;
      int dayMillis = now.hour * 3600000 + now.minute * 60000 + now.second * 1000 + now.millisecond;
      if (enabledMode == 1) {
        for (var item in shiftPlan) {
          if (item.day == day && dayMillis >= item.start && dayMillis <= item.end) return true;
        }

        return false;
      } else if (enabledMode == 2) {
        for (var item in shiftPlan) {
          if (item.day == day && dayMillis >= item.start && dayMillis <= item.end) return false;
        }

        return true;
      }
    }

    // if geofencing is not empty and enabledMode is 3, check if we are in an enabled area
    if (enabledMode == 3 && currentPosition != null) {
      for (var item in geofencing) {
        try {
          double distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            item.position.latitude,
            item.position.longitude,
          );

          if (distance < item.radius) return true;
        } catch (_) {}
      }

      return false;
    }

    return true;
  }

  static const Map<String, String> jsonShorts = {
    "stationId": "s",
    "manualOverride": "m",
    "calendar": "c",
    "enabledMode": "e",
    "shiftPlan": "sp",
    "geofencing": "g",
  };

  Map<String, dynamic> toJson() {
    DateTime now = DateTime.now();
    calendar.removeWhere((element) => element.end.isBefore(now) || element.end.isBefore(element.start));
    return {
      if (manualOverride != 1) jsonShorts["manualOverride"]!: manualOverride,
      if (calendar.isNotEmpty) jsonShorts["calendar"]!: calendar.map((e) => "${e.start.millisecondsSinceEpoch};${e.end.millisecondsSinceEpoch}").toList(),
      if (enabledMode != 0) jsonShorts["enabledMode"]!: enabledMode,
      if (shiftPlan.isNotEmpty) jsonShorts["shiftPlan"]!: shiftPlan.map((e) => "${e.day};${e.start};${e.end}").toList(),
      if (geofencing.isNotEmpty) jsonShorts["geofencing"]!: geofencing.map((e) => "${e.position.latitude};${e.position.longitude};${e.radius}").toList(),
    };
  }

  factory SettingsNotificationData.fromJson(String stationId, Map<String, dynamic> json) {
    int manualOverride = json[jsonShorts["manualOverride"]] ?? 1;

    List<dynamic> calendar = json[jsonShorts["calendar"]] ?? [];
    List<({DateTime start, DateTime end})> calendarList = [];
    DateTime now = DateTime.now();
    for (String item in calendar) {
      try {
        List<String> split = item.split(";");
        DateTime start = DateTime.fromMillisecondsSinceEpoch(int.parse(split[0]));
        DateTime end = DateTime.fromMillisecondsSinceEpoch(int.parse(split[1]));
        if (end.isBefore(start)) continue;
        if (end.isBefore(now)) continue;
        calendarList.add((
          start: start,
          end: end,
        ));
      } catch (_) {}
    }

    int enabledMode = json[jsonShorts["enabledMode"]] ?? 0;

    List<dynamic> shiftPlan = json[jsonShorts["shiftPlan"]] ?? [];
    List<({int day, int start, int end})> shiftPlanList = [];
    for (String item in shiftPlan) {
      try {
        List<String> split = item.split(";");
        int day = int.parse(split[0]);
        if (day < 0 || day > 6) continue;
        shiftPlanList.add((
          day: int.parse(split[0]),
          start: int.parse(split[1]),
          end: int.parse(split[2]),
        ));
      } catch (_) {}
    }

    List<dynamic> geofencing = json[jsonShorts["geofencing"]] ?? [];
    List<({LatLng position, int radius})> geofencingList = [];
    for (String item in geofencing) {
      try {
        List<String> split = item.split(";");
        geofencingList.add((
          position: LatLng(double.parse(split[0]), double.parse(split[1])),
          radius: int.parse(split[2]),
        ));
      } catch (_) {}
    }

    return SettingsNotificationData(
      stationId: stationId,
      manualOverride: manualOverride,
      calendar: calendarList,
      enabledMode: enabledMode,
      shiftPlan: shiftPlanList,
      geofencing: geofencingList,
    );
  }

  static Map<String, dynamic> toJsonServer(Map<String, SettingsNotificationData> responses, String server) {
    Map<String, dynamic> json = {};
    for (var entry in responses.entries) {
      if (entry.value.server != server) continue;
      try {
        json[entry.value.stationIdNumber.toString()] = entry.value.toJson();
      } catch (_) {}
    }
    return json;
  }

  static Map<String, SettingsNotificationData> fromJsonServer(Map<String, dynamic> json, String server) {
    Map<String, SettingsNotificationData> responses = {};
    for (var entry in json.entries) {
      try {
        responses["$server ${entry.key}"] = SettingsNotificationData.fromJson("$server ${entry.key}", entry.value);
      } catch (_) {}
    }
    return responses;
  }

  static SettingsNotificationData loadForStation(String stationId) {
    File file = File("${Globals.filesPath}/notification_settings.json");
    if (!file.existsSync()) return SettingsNotificationData.make(stationId: stationId);

    try {
      Map<String, dynamic> json = jsonDecode(file.readAsStringSync());
      if (!json.containsKey(stationId)) return SettingsNotificationData.make(stationId: stationId);
      return SettingsNotificationData.fromJson(stationId, json[stationId]);
    } catch (_) {
      return SettingsNotificationData.make(stationId: stationId);
    }
  }

  void save() {
    File file = File("${Globals.filesPath}/notification_settings.json");
    Map<String, dynamic> json;
    if (file.existsSync()) {
      try {
        json = jsonDecode(file.readAsStringSync());
      } catch (_) {
        json = {};
      }
    } else {
      json = {};
    }

    json[stationId] = toJson();
    file.writeAsStringSync(jsonEncode(json));

    UpdateInfo(UpdateType.ui, {"3"});
  }

  static Map<String, SettingsNotificationData> getAll() {
    File file = File("${Globals.filesPath}/notification_settings.json");
    if (!file.existsSync()) return {};

    try {
      Map<String, dynamic> json = jsonDecode(file.readAsStringSync());
      Map<String, SettingsNotificationData> result = {};
      for (String key in json.keys) {
        try {
          result[key] = SettingsNotificationData.fromJson(key, json[key]);
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}

class SettingsAlarmInformationPage extends StatefulWidget {
  const SettingsAlarmInformationPage({super.key, required this.stationId});

  final String stationId;

  @override
  State<SettingsAlarmInformationPage> createState() => _SettingsAlarmInformationPageState();
}

class _SettingsAlarmInformationPageState extends State<SettingsAlarmInformationPage> with Updates {
  Station? station;
  late SettingsNotificationData onEntry;
  late SettingsNotificationData current;
  bool loading = true;

  bool locationPermissionGranted = false;
  Timer? locationPermissionTimer;

  @override
  void initState() {
    super.initState();
    loadStation();
    setupListener({UpdateType.station, UpdateType.ui});

    current = SettingsNotificationData.loadForStation(widget.stationId);
    onEntry = SettingsNotificationData.loadForStation(widget.stationId);

    Permission.locationAlways.isGranted.then((value) {
      if (mounted) {
        setState(() {
          locationPermissionGranted = value;
        });
      }
    });

    locationPermissionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      Permission.locationAlways.isGranted.then((value) {
        if (mounted) {
          setState(() {
            locationPermissionGranted = value;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    locationPermissionTimer?.cancel();
    super.dispose();
  }

  Future<void> loadStation() async {
    station = await Globals.db.stationDao.getById(widget.stationId);
    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  bool hasChanges() {
    if (current.manualOverride != onEntry.manualOverride) return true;

    if (current.calendar.length != onEntry.calendar.length) return true;
    for (int i = 0; i < current.calendar.length; i++) {
      if (current.calendar[i].start != onEntry.calendar[i].start) return true;
      if (current.calendar[i].end != onEntry.calendar[i].end) return true;
    }

    if (current.enabledMode != onEntry.enabledMode) return true;

    if (current.shiftPlan.length != onEntry.shiftPlan.length) return true;
    for (int i = 0; i < current.shiftPlan.length; i++) {
      if (current.shiftPlan[i].day != onEntry.shiftPlan[i].day) return true;
      if (current.shiftPlan[i].start != onEntry.shiftPlan[i].start) return true;
      if (current.shiftPlan[i].end != onEntry.shiftPlan[i].end) return true;
    }

    if (current.geofencing.length != onEntry.geofencing.length) return true;
    for (int i = 0; i < current.geofencing.length; i++) {
      if (current.geofencing[i].position != onEntry.geofencing[i].position) return true;
      if (current.geofencing[i].radius != onEntry.geofencing[i].radius) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox();
    if (this.station == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Bereitschaftseinstellung")),
        body: const Center(child: Text("Station konnte nicht geladen werden")),
      );
    }
    Station station = this.station!;

    LatLng? lastPosition;
    if (Globals.lastPosition != null) {
      lastPosition = Formats.positionToLatLng(Globals.lastPosition!);
    }
    bool notify = current.shouldNotify(lastPosition);

    return PopScope(
      canPop: !hasChanges(),
      onPopInvoked: (bool didPop) {
        if (didPop) return;

        generalDialog(
          color: Colors.blue,
          title: "Änderungen verwerfen",
          content: const Text("Möchtest Du deine Änderungen verwerfen?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text("Verwerfen"),
            ),
          ],
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Bereitschaftseinstellung"),
        ),
        floatingActionButton: hasChanges()
            ? FloatingActionButton(
                onPressed: () async {
                  bool? confirm = await generalDialog(
                    color: Colors.blue,
                    title: "Speichern",
                    content: const Text("Möchtest Du deine Änderungen speichern?\n\n"
                        "Deine Bereitschaftseinstellung wird mit den Servern synchronisiert und füllt eine Absage im Bedarfsfall automatisch aus.\n\n"
                        "Du kannst trotzdem jederzeit die Absage in einer Alarmierung manuell überschreiben."),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: const Text("Abbrechen"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: const Text("Speichern"),
                      ),
                    ],
                  );
                  if (confirm != true) return;

                  Globals.context!.loaderOverlay.show();
                  try {
                    var all = SettingsNotificationData.getAll();
                    all[current.stationId] = current;
                    var serverJson = SettingsNotificationData.toJsonServer(all, current.server);

                    await Request("personSetResponse", serverJson, current.server).emit(true);
                    current.save();
                    onEntry = SettingsNotificationData.loadForStation(current.stationId);
                    if (mounted) setState(() {});
                    Globals.context!.loaderOverlay.hide();
                    successToast("Einstellungen erfolgreich gespeichert");
                  } catch (e, s) {
                    exceptionToast(e, s);
                    Globals.context!.loaderOverlay.hide();
                  }
                },
                backgroundColor: Colors.blue,
                child: const Icon(Icons.save_outlined),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            ListTile(
              title: const Text("Station"),
              subtitle: Text(station.name),
            ),
            const SettingsDivider(text: "Alarmierungs-Einstellungen"),
            Center(
              child: CustomToggleButtons(
                onPressed: (index) {
                  setState(() {
                    current.manualOverride = index;
                  });
                },
                selectedIndex: current.manualOverride,
                iconList: const [Icons.cancel_outlined, Icons.keyboard_double_arrow_down_outlined, Icons.check_circle_outline],
                textList: const ["Alle absagen", "Siehe unten", "Alle an"],
              ),
            ),
            if (current.manualOverride == 1) ...[
              const SizedBox(height: 10),
              Text("Deaktiviert an folgenden Tagen:", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              // list all datetime ranges
              for (var item in current.calendar) ...[
                ListTile(
                  title: Text("${DateFormat("dd.MM.yyyy").format(item.start)}  bis  ${DateFormat("dd.MM.yyyy").format(item.end.subtract(const Duration(days: 1)))}"),
                  subtitle: Text("Dauer: ${item.end.difference(item.start).inDays} Tage"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        current.calendar.remove(item);
                      });
                    },
                  ),
                ),
              ],
              if (current.calendar.isNotEmpty) const SizedBox(height: 5),
              ElevatedButton(
                onPressed: () async {
                  DateTimeRange? range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (range == null) return;

                  setState(() {
                    current.calendar.add((start: range.start, end: range.end.add(const Duration(days: 1))));
                  });
                },
                child: const Text("Zeitraum hinzufügen"),
              ),
              const SizedBox(height: 10),

              const SettingsDivider(text: "Dynamische Einstellungen"),
              CustomToggleButtons(
                onPressed: (index) {
                  setState(() {
                    current.enabledMode = index;
                  });
                },
                selectedIndex: current.enabledMode,
                iconList: const [Icons.check_circle_outline, Icons.check_box_outlined, Icons.indeterminate_check_box_outlined, Icons.location_on_outlined],
                textList: const ["Alle an", "Schichtplan (Aktiviert)", "Schichtplan (Deaktiviert)", "Geofencing"],
              ),

              if (current.enabledMode != 0) ...[
                const SizedBox(height: 10),
                if (current.enabledMode == 3 && !locationPermissionGranted) ...[
                  Text("Standortberechtigung fehlt", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 5),
                  ElevatedButton(
                    onPressed: () async {
                      LifeCycleSettingsState.requestLocationPermission();
                    },
                    child: const Text("Berechtigung erteilen"),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) {
    if (info.type == UpdateType.station && info.ids.contains(widget.stationId)) {
      loadStation();
    }
    if (info.type == UpdateType.ui && info.ids.contains("2")) {
      if (mounted) setState(() {});
    }
  }
}

class CustomToggleButtons extends StatefulWidget {
  const CustomToggleButtons({
    super.key,
    required this.onPressed,
    required this.selectedIndex,
    required this.iconList,
    required this.textList,
  });

  final void Function(int) onPressed;
  final int selectedIndex;
  final List<IconData> iconList;
  final List<String> textList;

  @override
  State<CustomToggleButtons> createState() => CustomToggleButtonsState();
}

class CustomToggleButtonsState extends State<CustomToggleButtons> {
  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      onPressed: (index) => widget.onPressed(index),
      isSelected: [for (int i = 0; i < widget.iconList.length; i++) widget.selectedIndex == i],
      borderRadius: BorderRadius.circular(30),
      children: () {
        List<Widget> children = [];
        for (int i = 0; i < widget.iconList.length; i++) {
          final isSelected = widget.selectedIndex == i;
          children.add(
            SizedBox(
              width: isSelected ? MediaQuery.of(context).size.width - 25 - (70 * (widget.iconList.length - 1)) : 70,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSelected ? 5 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.iconList[i]),
                    const SizedBox(width: 5),
                    Flexible(child: Text(isSelected ? widget.textList[i] : '')),
                  ],
                ),
              ),
            ),
          );
        }
        return children;
      }(),
    );
  }
}
