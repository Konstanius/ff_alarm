import 'dart:async';

import 'package:ff_alarm/data/interfaces/station_interface.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/no_data.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key, required this.badge});

  final ValueNotifier<int> badge;

  @override
  State<UnitsScreen> createState() => UnitsScreenState();
}

class UnitsScreenState extends State<UnitsScreen> with AutomaticKeepAliveClientMixin, Updates {
  @override
  bool get wantKeepAlive => true;

  bool loading = true;
  List<Unit> units = [];
  List<Station> stations = [];

  Timer? timer;
  Map<String, dynamic> notifyInformation = {};
  DateTime notifyInfoTime = DateTime.now();

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.unit, UpdateType.station, UpdateType.ui});

    timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!Globals.foreground || stations.isEmpty) return;
      StationInterface.getNotifyInformation(stations.map((e) => e.server).toSet().toList()).then((value) {
        if (!mounted) return;
        setState(() {
          notifyInformation = value;
          notifyInfoTime = DateTime.now();
        });
      });
    });

    if (Globals.localPersons.isEmpty) return;

    Station.getAll(
      filter: (station) {
        for (var person in station.personProperIds) {
          if (Globals.localPersons.keys.any((element) => element == person)) {
            return true;
          }
        }
        return false;
      },
    ).then((List<Station> value) {
      if (!mounted) return;
      setState(() {
        loading = false;
        stations = value;
        stations.sort((a, b) => a.descriptiveName.compareTo(b.descriptiveName));
      });

      if (stations.isNotEmpty) {
        StationInterface.getNotifyInformation(stations.map((e) => e.server).toSet().toList()).then((value) {
          if (!mounted) return;
          setState(() {
            notifyInformation = value;
            notifyInfoTime = DateTime.now();
          });
        });
      }
    });

    Unit.getAll().then((List<Unit> value) {
      if (!mounted) return;
      setState(() {
        units = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Widget bodyWidget;
    if (loading) {
      bodyWidget = const SizedBox();
    } else if (stations.isEmpty) {
      bodyWidget = const NoDataWidget(text: 'Du bist nicht Mitglied einer Wache');
    } else {
      bodyWidget = ListView(
        padding: const EdgeInsets.all(8),
        children: [
          for (var station in stations)
            () {
              var stationUnits = units.where((u) => u.stationProperId == station.id).toList();
              return Card(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 10,
                child: ListTile(
                  onTap: () {
                    Globals.router.push('/station', extra: station.id);
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.descriptiveName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: kDefaultFontSize * 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  subtitle: Column(
                    children: [
                      for (var unit in stationUnits) unitCard(unit, station, const EdgeInsets.symmetric(horizontal: 2, vertical: 4), true),
                      if (notifyInformation.containsKey(station.id)) const SizedBox(height: 8),
                      if (notifyInformation.containsKey(station.id))
                        () {
                          var info = notifyInformation[station.id];

                          int totalY = info["yT"];
                          int totalN = info["nT"];
                          int totalU = info["uT"];

                          Map<String, int> y = info["y"].cast<String, int>();
                          Map<String, int> n = info["n"].cast<String, int>();
                          Map<String, int> u = info["u"].cast<String, int>();

                          List<({String type, int y, int u, int n})> sorted = [];
                          for (var key in y.keys) {
                            String type = key;
                            int yV = y[key] ?? 0;
                            int nV = n[key] ?? 0;
                            int uV = u[key] ?? 0;

                            sorted.add((type: type, y: yV, u: uV, n: nV));
                          }
                          for (var key in n.keys) {
                            if (sorted.any((element) => element.type == key)) continue;
                            String type = key;
                            int yV = y[key] ?? 0;
                            int nV = n[key] ?? 0;
                            int uV = u[key] ?? 0;

                            sorted.add((type: type, y: yV, u: uV, n: nV));
                          }
                          for (var key in u.keys) {
                            if (sorted.any((element) => element.type == key)) continue;
                            String type = key;
                            int yV = y[key] ?? 0;
                            int nV = n[key] ?? 0;
                            int uV = u[key] ?? 0;

                            sorted.add((type: type, y: yV, u: uV, n: nV));
                          }

                          sorted.sort((a, b) => a.type.compareTo(b.type));

                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ColoredBox(
                                        color: Colors.blue.withOpacity(0.7),
                                        child: Column(
                                          children: [
                                            const Text(" "),
                                            const Text("Gesamt", style: TextStyle(fontWeight: FontWeight.bold)),
                                            const Divider(color: Colors.white),
                                            for (var item in sorted) ...[
                                              Text(item.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ColoredBox(
                                        color: Colors.green.withOpacity(0.7),
                                        child: Column(
                                          children: [
                                            const Text("Verfügbar"),
                                            Text("$totalY", style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const Divider(),
                                            for (var item in sorted) Text("${item.y}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ColoredBox(
                                        color: Colors.amber.withOpacity(0.7),
                                        child: Column(
                                          children: [
                                            const Text("Keine Info"),
                                            Text("$totalU", style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const Divider(),
                                            for (var item in sorted) Text("${item.u}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ColoredBox(
                                        color: Colors.red.withOpacity(0.7),
                                        child: Column(
                                          children: [
                                            const Text("Abwesend"),
                                            Text("$totalN", style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const Divider(),
                                            for (var item in sorted) Text("${item.n}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    "Stand: ${notifyInfoTime.hour.toString().padLeft(2, '0')}:${notifyInfoTime.minute.toString().padLeft(2, '0')}:${notifyInfoTime.second.toString().padLeft(2, '0')}    ",
                                    style: const TextStyle(fontSize: kDefaultFontSize * 0.8, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }(),
                    ],
                  ),
                ),
              );
            }(),
          const SizedBox(height: kBottomNavigationBarHeight),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wachen & Einheiten'),
      ),
      body: bodyWidget,
    );
  }

  static Widget unitCard(Unit unit, Station station, margin, bool canClick) {
    return Card(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      elevation: 2,
      margin: margin,
      child: ListTile(
        onTap: canClick
            ? () {
                Globals.router.push('/unit', extra: unit.id);
              }
            : null,
        title: Text(
          unit.callSign,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: kDefaultFontSize * 1.2,
          ),
        ),
        subtitle: Text("${unit.unitDescription}  ( ${unit.positionsDescription} )"),
        trailing: () {
          var status = UnitStatus.fromInt(unit.status);
          if (status == UnitStatus.invalid) return const SizedBox();
          return Text(
            status.value.toString(),
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.bold,
              fontSize: kDefaultFontSize * 1.6,
            ),
          );
        }(),
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.unit) {
      Set<String> ids = {...info.ids};
      var futures = <Future<Unit?>>[];
      for (var id in info.ids) {
        futures.add(Globals.db.unitDao.getById(id));
      }
      var newUnits = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        for (var unit in newUnits) {
          if (unit != null) {
            units.removeWhere((u) => u.id == unit.id);
            units.add(unit);
            ids.remove(unit.id);
          }
        }
        units.removeWhere((u) => ids.contains(u.id));
      });
    } else if (info.type == UpdateType.station) {
      Set<String> ids = {...info.ids};
      var futures = <Future<Station?>>[];
      for (var id in info.ids) {
        futures.add(Globals.db.stationDao.getById(id));
      }
      var newStations = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        for (var station in newStations) {
          if (station != null) {
            stations.removeWhere((s) => s.id == station.id);
            stations.add(station);
            stations.sort((a, b) => a.descriptiveName.compareTo(b.descriptiveName));
            ids.remove(station.id);
          }
        }
        stations.removeWhere((s) => ids.contains(s.id));
      });
    } else if (info.type == UpdateType.ui && info.ids.contains("3")) {
      if (Globals.localPersons.isNotEmpty) {
        stations.clear();
        units.clear();
        Station.getAll(
          filter: (station) {
            for (var person in station.personProperIds) {
              if (Globals.localPersons.keys.any((element) => element == person)) {
                return true;
              }
            }
            return false;
          },
        ).then((List<Station> value) {
          if (!mounted) return;
          setState(() {
            stations = value;
            stations.sort((a, b) => a.descriptiveName.compareTo(b.descriptiveName));
          });
        });

        Unit.getAll().then((List<Unit> value) {
          if (!mounted) return;
          setState(() {
            units = value;
          });
        });
      }
    }
  }
}
