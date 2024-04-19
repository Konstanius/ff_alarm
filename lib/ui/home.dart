import 'dart:async';
import 'dart:io';

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
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:responsive_navigation_bar/responsive_navigation_bar.dart';
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
      if (pageController.page!.round() != currentPage.value) currentPage.value = pageController.page!.round();
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
    super.dispose();
  }

  final ValueNotifier<int> badgeAlarms = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeCalendar = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeUnits = ValueNotifier<int>(0);
  final ValueNotifier<int> badgeSettings = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBody: true,
        body: PageView(
          controller: pageController,
          children: <Widget>[
            AlarmsScreen(badge: badgeAlarms),
            CalendarScreen(badge: badgeCalendar),
            UnitsScreen(badge: badgeUnits),
            SettingsScreen(badge: badgeSettings),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder(
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
                  backgroundColor: Colors.blue.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
                NavigationBarButton(
                  icon: Icons.calendar_month_outlined,
                  text: 'Kalender',
                  backgroundColor: Colors.blue.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
                NavigationBarButton(
                  icon: Icons.fire_truck_outlined,
                  text: 'Einheiten',
                  backgroundColor: Colors.blue.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
                NavigationBarButton(
                  icon: Icons.settings_outlined,
                  text: 'Einstellungen',
                  backgroundColor: Colors.blue.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
