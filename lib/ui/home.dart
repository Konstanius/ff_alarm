import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/interfaces/station_interface.dart';
import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/home/alarms_screen.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/home/units_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

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

  @override
  void initState() {
    super.initState();

    Globals.appStarted = true;
    tabController = TabController(length: 3, vsync: this);

    PersonInterface.fetchAll();
    UnitInterface.fetchAll();
    StationInterface.fetchAll();
    AlarmInterface.fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          body: TabBarView(
            controller: tabController,
            children: const <Widget>[
              AlarmsScreen(),
              UnitsScreen(),
              SettingsScreen(),
            ],
          ),
          bottomNavigationBar: Card(
            margin: EdgeInsets.zero,
            elevation: 5,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            color: Theme.of(context).focusColor,
            child: TabBar(
              controller: tabController,
              tabs: const <Tab>[
                Tab(
                  child: Column(children: <Widget>[
                    SizedBox(height: 6),
                    Icon(Icons.notifications_active_outlined),
                    Text('Alarmierungen', textScaler: TextScaler.linear(0.8)),
                  ]),
                ),
                Tab(
                  child: Column(children: <Widget>[
                    SizedBox(height: 6),
                    Icon(Icons.fire_truck_outlined),
                    Text('Einheiten', textScaler: TextScaler.linear(0.8)),
                  ]),
                ),
                Tab(
                  child: Column(children: <Widget>[
                    SizedBox(height: 6),
                    Icon(Icons.settings_outlined),
                    Text('Einstellungen', textScaler: TextScaler.linear(0.8)),
                  ]),
                ),
              ],
            ),
          )),
    );
  }
}
