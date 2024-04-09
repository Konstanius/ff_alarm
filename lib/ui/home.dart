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
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';

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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver, Updates {
  late final TabController tabController;

  Timer? _timer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!Globals.foreground && state == AppLifecycleState.resumed) {
      UpdateInfo(UpdateType.ui, {"0"});
      AwesomeNotifications().dismissNotificationsByChannelKey('alarm');
      AwesomeNotifications().dismissNotificationsByChannelKey('test');
      AwesomeNotifications().cancelNotificationsByChannelKey('alarm');
      AwesomeNotifications().cancelNotificationsByChannelKey('test');
      resetAndroidNotificationVolume();

      RealTimeListener.initAll();

      PersonInterface.fetchAll();
      UnitInterface.fetchAll();
      StationInterface.fetchAll();
      AlarmInterface.fetchAll();
    } else if (Globals.foreground && state != AppLifecycleState.resumed) {
      for (var listener in RealTimeListener.listeners.values) {
        listener.socket?.close();
      }
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

    Future.delayed(const Duration(seconds: 2), () {
      Globals.fastStartBypass = false;
    });

    () async {
      badgeSettings.value = await SettingsScreenState.getBadLifeCycle() + await SettingsScreenState.getBadNotificationsAmount();

      if (Globals.localPersons.isEmpty || badgeSettings.value == 0) return;

      showPermissionsPopup();
    }();

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      RealTimeListener.initAll();
    });

    setupListener({UpdateType.ui});

    RealTimeListener.initAll();

    if (Globals.localPersons.isNotEmpty) {
      PersonInterface.fetchAll();
      UnitInterface.fetchAll();
      StationInterface.fetchAll();
      AlarmInterface.fetchAll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        Globals.router.go('/login');
      });
    }
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
              tabs: <Tab>[
                Tab(
                  child: Column(children: <Widget>[
                    const SizedBox(height: 6),
                    ValueListenableBuilder(
                        valueListenable: badgeAlarms,
                        builder: (context, value, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_outlined),
                              if (value > 0) Text(' $value !', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          );
                        }),
                    const Text('Alarmierungen', textScaler: TextScaler.linear(0.8)),
                  ]),
                ),
                Tab(
                  child: Column(children: <Widget>[
                    const SizedBox(height: 6),
                    ValueListenableBuilder(
                        valueListenable: badgeUnits,
                        builder: (context, value, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fire_truck_outlined),
                              if (value > 0) Text(' $value !', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          );
                        }),
                    const Text('Einheiten', textScaler: TextScaler.linear(0.8)),
                  ]),
                ),
                Tab(
                  child: Column(children: <Widget>[
                    const SizedBox(height: 6),
                    ValueListenableBuilder(
                        valueListenable: badgeSettings,
                        builder: (context, value, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.settings_outlined),
                              if (value > 0) Text(' $value !', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          );
                        }),
                    const Text('Einstellungen', textScaler: TextScaler.linear(0.8)),
                  ]),
                ),
              ],
            ),
          )),
    );
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.ui) {
      if (info.ids.contains("1")) {
        badgeSettings.value = await SettingsScreenState.getBadLifeCycle() + await SettingsScreenState.getBadNotificationsAmount();
      }

      if (info.ids.contains("3")) {
        int bad = await SettingsScreenState.getBadLifeCycle() + await SettingsScreenState.getBadNotificationsAmount();
        badgeSettings.value = bad;
        if (Globals.localPersons.isNotEmpty && badgeSettings.value > 0) {
          showPermissionsPopup();
        }
      }
    }
  }

  void showPermissionsPopup() {
    generalDialog(
      color: Colors.red,
      title: badgeSettings.value > 1 ? 'Aktionen erforderlich' : 'Aktion erforderlich',
      content: const Text('Die Einstellungen und Berechtigungen der App auf deinem Handy sind nicht vollständig. Bitte überprüfe die Einstellungen.'),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Ignorieren'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            tabController.index = 2;
          },
          child: const Text('Einstellungen'),
        ),
      ],
    );
  }
}
