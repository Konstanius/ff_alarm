import 'dart:async';
import 'dart:io';

import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/interfaces/station_interface.dart';
import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/realtime.dart';
import 'package:ff_alarm/ui/home/alarms_screen.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/home/units_screen.dart';
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/responsive_navigation_bar.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home/calendar_screen.dart';

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
      builder: (context, child) {
        return LoaderOverlay(
          closeOnBackButton: false,
          disableBackButton: true,
          overlayColor: Colors.black.withOpacity(0.5),
          overlayWholeScreen: true,
          child: child!,
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, Updates {
  final PageController pageController = PageController();
  final ValueNotifier<int> currentPage = ValueNotifier<int>(0);

  Timer? _timer;

  static int lastUpdate = DateTime.now().millisecondsSinceEpoch;

  ValueNotifier<List<Widget>> actionWidgets = ValueNotifier<List<Widget>>([]);
  Map<int, List<Widget>> savedActionWidgets = {};

  void setActionWidgets(List<Widget> widgets, int page) {
    savedActionWidgets[page] = widgets;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      actionWidgets.value = widgets;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!Globals.foreground && state == AppLifecycleState.resumed) {
      UpdateInfo(UpdateType.ui, {"0"});

      if (lastUpdate + 10000 > DateTime.now().millisecondsSinceEpoch) {
        Globals.foreground = state == AppLifecycleState.resumed;
        return;
      }
      lastUpdate = DateTime.now().millisecondsSinceEpoch;
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

    Future.delayed(const Duration(seconds: 2), () {
      Globals.fastStartBypass = false;
    });

    () async {
      badgeSettings.value = await SettingsScreenState.getBadLifeCycle() + await SettingsScreenState.getBadNotificationsAmount();

      if (Globals.localPersons.isEmpty) return;

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

    pageController.addListener(() {
      if (pageController.page!.round() != currentPage.value) {
        currentPage.value = pageController.page!.round();
      }
    });

    currentPage.addListener(() {
      if (savedActionWidgets.containsKey(currentPage.value)) {
        actionWidgets.value = savedActionWidgets[currentPage.value]!;
      } else {
        actionWidgets.value = [];
      }
    });

    badgeAlarms.addListener(() {
      combinedNotifier.value = (alarms: badgeAlarms.value, calendar: badgeCalendar.value, units: badgeUnits.value, settings: badgeSettings.value);
    });

    badgeCalendar.addListener(() {
      combinedNotifier.value = (alarms: badgeAlarms.value, calendar: badgeCalendar.value, units: badgeUnits.value, settings: badgeSettings.value);
    });

    badgeUnits.addListener(() {
      combinedNotifier.value = (alarms: badgeAlarms.value, calendar: badgeCalendar.value, units: badgeUnits.value, settings: badgeSettings.value);
    });

    badgeSettings.addListener(() {
      combinedNotifier.value = (alarms: badgeAlarms.value, calendar: badgeCalendar.value, units: badgeUnits.value, settings: badgeSettings.value);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    pageController.dispose();
    currentPage.dispose();
    WidgetsBinding.instance.removeObserver(this);

    badgeAlarms.dispose();
    badgeCalendar.dispose();
    badgeUnits.dispose();
    badgeSettings.dispose();

    combinedNotifier.dispose();
    super.dispose();
  }

  final ValueNotifier<int> badgeAlarms = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeCalendar = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeUnits = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeSettings = ValueNotifier<int>(0);

  final ValueNotifier<({int alarms, int calendar, int units, int settings})> combinedNotifier = ValueNotifier((alarms: 0, calendar: 0, units: 0, settings: 0));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FF Alarm'),
          actions: [
            ValueListenableBuilder(
              valueListenable: actionWidgets,
              builder: (context, widgets, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: widgets,
                );
              },
            ),
          ],
        ),
        extendBody: true,
        body: PageView(
          controller: pageController,
          children: <Widget>[
            AlarmsScreen(badge: badgeAlarms, setActionWidgets: (List<Widget> widgets) => setActionWidgets(widgets, 0)),
            CalendarScreen(badge: badgeCalendar, setActionWidgets: (List<Widget> widgets) => setActionWidgets(widgets, 1)),
            UnitsScreen(badge: badgeUnits, setActionWidgets: (List<Widget> widgets) => setActionWidgets(widgets, 2)),
            SettingsScreen(badge: badgeSettings, setActionWidgets: (List<Widget> widgets) => setActionWidgets(widgets, 3)),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: combinedNotifier,
          builder: (context, badges, child) {
            return ValueListenableBuilder(
              valueListenable: currentPage,
              builder: (context, currentTab, child) {
                return ResponsiveNavigationBar(
                  selectedIndex: currentTab,
                  backgroundColor: Theme.of(context).dialogBackgroundColor,
                  fontSize: kDefaultFontSize * 1.2,
                  activeButtonFlexFactor: 200,
                  inactiveButtonsFlexFactor: 60,
                  navigationBarButtons: [
                    NavigationBarButton(
                      icon: Icons.local_fire_department_outlined,
                      text: 'Alarmierungen',
                      badge: badges.alarms > 0 ? badges.alarms.toString() : null,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      backgroundGradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 255, 0, 0),
                          Color.fromARGB(255, 255, 165, 0),
                        ],
                      ),
                    ),
                    NavigationBarButton(
                      icon: Icons.calendar_month_outlined,
                      text: 'Kalender',
                      badge: badges.calendar > 0 ? badges.calendar.toString() : null,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      backgroundGradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 4, 147, 4),
                          Color.fromARGB(255, 11, 178, 102),
                        ],
                      ),
                    ),
                    NavigationBarButton(
                      icon: Icons.fire_truck_outlined,
                      text: 'Einheiten',
                      badge: badges.units > 0 ? badges.units.toString() : null,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      backgroundGradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 0, 0, 255),
                          Color.fromARGB(255, 0, 119, 255),
                        ],
                      ),
                    ),
                    NavigationBarButton(
                      icon: Icons.settings_outlined,
                      text: 'Einstellungen',
                      badge: badges.settings > 0 ? badges.settings.toString() : null,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      backgroundGradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 50, 50, 50),
                          Color.fromARGB(255, 100, 100, 100),
                        ],
                      ),
                    ),
                  ],
                  onTabChange: (index) {
                    pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
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
        if (Globals.localPersons.isNotEmpty) {
          showPermissionsPopup();
        }
      }
    }
  }

  void showPermissionsPopup() async {
    if (badgeSettings.value > 0) {
      await generalDialog(
        color: Colors.red,
        title: badgeSettings.value > 1 ? 'Aktionen erforderlich' : 'Aktion erforderlich',
        content: const Text('Die Einstellungen und Berechtigungen der App auf deinem Handy sind nicht vollständig. Bitte überprüfe die Einstellungen.'),
        actions: [
          DialogActionButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            text: 'Ignorieren',
          ),
          DialogActionButton(
            onPressed: () {
              Navigator.of(context).pop();
              pageController.animateToPage(3, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            text: 'Einstellungen',
          ),
        ],
      );
    }

    var settings = SettingsNotificationData.getAll();
    bool anyGeofencing = false;
    for (var data in settings.values) {
      if (data.enabledMode == 3 && data.geofencing.isNotEmpty && data.manualOverride == 1) {
        anyGeofencing = true;
        break;
      }
    }
    if (!anyGeofencing) return;

    bool granted = await Permission.locationAlways.isGranted;
    if (granted && Platform.isIOS) {
      granted = await Permission.sensors.isGranted;
    }

    if (granted) return;

    await generalDialog(
      color: Colors.red,
      title: 'Aktion erforderlich',
      content: const Text('Die App benötigt Zugriff auf deinen Standort, um Geofencing zu verwenden. Bitte erlaube den Zugriff in den Einstellungen.'),
      actions: [
        DialogActionButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          text: 'Ignorieren',
        ),
        DialogActionButton(
          onPressed: () async {
            Navigator.of(context).pop();

            Globals.router.push('/lifecycle');
          },
          text: 'Einstellungen',
        ),
      ],
    );
  }
}
