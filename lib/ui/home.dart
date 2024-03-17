import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/interfaces/station_interface.dart';
import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/server/realtime.dart';
import 'package:ff_alarm/ui/home/alarms_screen.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/home/units_screen.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
      locale: const Locale('de', 'DE'),
      routerConfig: Globals.router,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController tabController;

  Timer? _timer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!Globals.foreground && state == AppLifecycleState.resumed) {
      UpdateInfo(UpdateType.ui, {0});
      AwesomeNotifications().dismissNotificationsByChannelKey('alarm');
      AwesomeNotifications().dismissNotificationsByChannelKey('test');
      AwesomeNotifications().cancelNotificationsByChannelKey('alarm');
      AwesomeNotifications().cancelNotificationsByChannelKey('test');
      resetAndroidNotificationVolume();

      RealTimeListener.init();

      PersonInterface.fetchAll();
      UnitInterface.fetchAll();
      StationInterface.fetchAll();
      AlarmInterface.fetchAll();
    } else if (Globals.foreground && state != AppLifecycleState.resumed) {
      RealTimeListener.socket?.close();
    }

    Globals.foreground = state == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    Globals.foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    Globals.appStarted = true;
    tabController = TabController(length: 3, vsync: this);

    PersonInterface.fetchAll();
    UnitInterface.fetchAll();
    StationInterface.fetchAll();
    AlarmInterface.fetchAll();

    Future.delayed(const Duration(seconds: 2), () {
      Globals.fastStartBypass = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      RealTimeListener.init();
    });

    RealTimeListener.init();

    Future.delayed(const Duration(seconds: 2)).then((value) {
      String? fcmToken = Globals.prefs.getString('fcm_token');
      Share.share('FCM Token: $fcmToken');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    badgeAlarms.dispose();
    badgeUnits.dispose();
    badgeSettings.dispose();
    super.dispose();
  }

  final ValueNotifier<int> badgeAlarms = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeUnits = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeSettings = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          body: TabBarView(
            controller: tabController,
            children: <Widget>[
              AlarmsScreen(badge: badgeAlarms),
              UnitsScreen(badge: badgeUnits),
              SettingsScreen(badge: badgeSettings),
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
                    Icon(Icons.local_fire_department_outlined),
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
