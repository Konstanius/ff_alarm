import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
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

  List<Unit> units = [];
  List<Station> stations = [];

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.unit, UpdateType.station, UpdateType.ui});

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
        stations = value;
        stations.sort((a, b) => a.name.compareTo(b.name));
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wachen & Einheiten'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: stations.length,
        itemBuilder: (BuildContext context, int index) {
          var station = stations[index];
          var stationUnits = units.where((u) => u.stationProperId == station.id).toList();
          return Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 10,
            child: ListTile(
              onTap: () {
                Globals.router.go('/station', extra: station.id);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 10),
                child: Text(
                  station.descriptiveName,
                  style: const TextStyle(
                    fontSize: kDefaultFontSize * 1.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              subtitle: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stationUnits.length,
                itemBuilder: (BuildContext context, int index) {
                  var unit = stationUnits[index];
                  return unitCard(unit, station, const EdgeInsets.symmetric(horizontal: 2, vertical: 4), true);
                },
              ),
            ),
          );
        },
      ),
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
                Globals.router.go('/unit', extra: unit.id);
              }
            : null,
        title: Text(
          unit.callSign(station),
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
            stations.sort((a, b) => a.name.compareTo(b.name));
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
