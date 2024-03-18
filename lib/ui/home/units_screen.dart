import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key, required this.badge});

  final ValueNotifier<int> badge;

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> with AutomaticKeepAliveClientMixin, Updates {
  @override
  bool get wantKeepAlive => true;

  List<Unit> units = [];
  List<Station> stations = [];

  @override
  void initState() {
    super.initState();
    setupListener({UpdateType.unit, UpdateType.station});

    Station.getAll().then((List<Station> value) {
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
        title: const Text('Units'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: stations.length,
        itemBuilder: (BuildContext context, int index) {
          var station = stations[index];
          var stationUnits = units.where((u) => u.stationId == station.id).toList();
          return ExpansionTile(
            title: Text(station.name),
            children: <Widget>[
              for (var unit in stationUnits)
                ListTile(
                  title: Text(unit.unitCallSign(station)),
                  subtitle: Text(unit.unitDescription),
                  onTap: () {},
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.unit) {
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
          }
        }
      });
    } else if (info.type == UpdateType.station) {
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
          }
        }
      });
    }
  }
}
