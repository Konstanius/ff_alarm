import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

class FFAlarmApp extends StatelessWidget {
  const FFAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FF Alarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: const ColorScheme.dark().copyWith(
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.blue,
          onSecondary: Colors.white,
        ),
      ),
      routerConfig: Globals.router,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController tabController;

  List<Station> stations = Globals.db.stations.where().findAllSync();
  List<Unit> units = Globals.db.units.where().findAllSync();
  Alarm? lastAlarm = Globals.db.alarms.where(sort: Sort.desc).findFirstSync();

  // TODO an icon in the top right to warn if configuration is not perfect (missing permissions, muted, etc.)

  @override
  void initState() {
    super.initState();

    Globals.appStarted = true;
    tabController = TabController(length: 2, vsync: this);

    if (lastAlarm != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        DateTime alertTime = DateTime.now().subtract(const Duration(minutes: 10));
        if (lastAlarm!.date.isAfter(alertTime)) {
          Globals.router.go('/alarm', extra: lastAlarm);
          return;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawerEnableOpenDragGesture: true,
      drawer: NavigationDrawer(
        children: [],
      ),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('FF Alarm'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                Globals.loggedIn = true;
                await Request('test', {}).emit(true);
              } on AckError catch (e) {
                Logger.red('Test request failed: ${e.errorMessage}');
              }
            },
            icon: const Icon(Icons.notification_important_outlined),
          ),
          if (lastAlarm != null && lastAlarm!.date.isAfter(DateTime.now().subtract(const Duration(minutes: 60))))
            IconButton(
              onPressed: () {
                Globals.router.go('/alarm', extra: lastAlarm);
              },
              icon: const Icon(Icons.warning_amber_outlined, color: Colors.amber),
            ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: tabController,
            tabs: const [
              Tab(text: 'Wachen / Fahrzeuge'),
              Tab(text: 'Alarmierungen'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                ListView.builder(
                  itemCount: stations.length,
                  itemBuilder: (BuildContext context, int index) {
                    Station station = stations[index];
                    List<Unit> stationUnits = units.where((element) => element.stationId == station.id).toList();
                    return StationCard(station: station, units: stationUnits);
                  },
                ),
                ListView.builder(
                  itemCount: 1,
                  itemBuilder: (BuildContext context, int index) {
                    return AlarmCard(alarm: lastAlarm!);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StationCard extends StatefulWidget {
  const StationCard({super.key, required this.station, required this.units});

  final Station station;
  final List<Unit> units;

  @override
  State<StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<StationCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(widget.station.name),
            subtitle: Text(widget.station.area),
            trailing: Text(widget.station.prefix + widget.station.stationNumber.toString()),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: widget.units.length,
            itemBuilder: (BuildContext context, int index) {
              Unit unit = widget.units[index];
              return UnitCard(unit: unit, station: widget.station);
            },
          ),
        ],
      ),
    );
  }
}

class UnitCard extends StatefulWidget {
  const UnitCard({super.key, required this.unit, required this.station});

  final Unit unit;
  final Station station;

  @override
  State<UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends State<UnitCard> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.unit.unitDescription),
      subtitle: Text(widget.unit.unitCallSign(widget.station)),
      trailing: Text(widget.unit.status.toString()),
    );
  }
}

class AlarmCard extends StatefulWidget {
  const AlarmCard({super.key, required this.alarm});

  final Alarm alarm;

  @override
  State<AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<AlarmCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(widget.alarm.type),
            subtitle: Text(widget.alarm.word),
            trailing: Text(widget.alarm.date.toString()),
          ),
          ListTile(
            title: Text(widget.alarm.address),
            subtitle: Column(
              children: widget.alarm.notes.map((e) => Text(e)).toList(),
            ),
            trailing: Text(widget.alarm.number.toString()),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: widget.alarm.units.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title: Text(widget.alarm.units[index].toString()),
              );
            },
          ),
        ],
      ),
    );
  }
}
