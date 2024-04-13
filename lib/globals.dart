import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:ff_alarm/data/database.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/prefs.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/main.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:ff_alarm/ui/popups/alarm_info.dart';
import 'package:ff_alarm/ui/popups/login_screen.dart';
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/settings/lifecycle.dart';
import 'package:ff_alarm/ui/settings/notifications.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

abstract class Globals {
  static const MethodChannel channel = MethodChannel('app.feuerwehr.jena.de/methods');

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ignore: close_sinks
  static StreamController<UpdateInfo> updateStream = StreamController<UpdateInfo>.broadcast();

  static BuildContext? get context => navigatorKey.currentContext;

  static late final String filesPath;
  static late final String cachePath;
  static late final Prefs prefs;
  static late final AppDatabase db;

  static Future<void> initialize() async {
    if (initialized) {
      await initializeTemporary();
      return;
    }
    initialized = true;
    if (!Platform.isIOS) {
      filesPath = (await getApplicationSupportDirectory()).path;
    } else {
      // Since we are trying to share assets with the app extension, we need to use the group directory
      filesPath = (await AppGroupDirectory.getAppGroupDirectory('group.de.jena.feuerwehr.app.ffAlarm'))!.path;
    }
    cachePath = (await getTemporaryDirectory()).path;

    prefs = Prefs(identifier: 'main');

    db = await $FloorAppDatabase.databaseBuilder('database.db').buildBetterPath();

    await initializeTemporary();
  }

  static Future<void> initGeoLocator() async {
    try {
      // check if permission is granted, else throw
      if (!await Geolocator.isLocationServiceEnabled()) {
        lastPosition = null;
        lastPositionTime = null;
        throw 'Location service is disabled';
      }

      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        lastPosition = null;
        lastPositionTime = null;
        throw 'Location permission is denied';
      }

      // read last location from file
      try {
        String path = '$filesPath/last_location.txt';
        File file = File(path);
        if (file.existsSync()) {
          List<String> parts = file.readAsStringSync().split(',');
          if (parts.length == 3) {
            double lat = double.tryParse(parts[0]) ?? 0;
            double lon = double.tryParse(parts[1]) ?? 0;
            int time = int.tryParse(parts[2]) ?? 0;
            lastPosition = Position(
              latitude: lat,
              longitude: lon,
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
              timestamp: DateTime.now(),
              floor: 0,
              isMocked: false,
            );
            lastPositionTime = DateTime.fromMillisecondsSinceEpoch(time);
          }
        }
      } catch (e, s) {
        Logger.warn('Failed to read last location: $e\n$s');
      }

      if (positionSubscription != null) {
        positionSubscription!.cancel();
        positionSubscription = null;
      }

      positionSubscription = Geolocator.getPositionStream().listen((Position position) {
        if (lastPositionTime != null && DateTime.now().difference(lastPositionTime!) < const Duration(seconds: 3)) return;
        lastPosition = position;
        lastPositionTime = DateTime.now();
        UpdateInfo(UpdateType.ui, {"2"});
      });

      // get initial position
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 5)).then((Position? position) {
        lastPosition = position;
        lastPositionTime = DateTime.now();
        UpdateInfo(UpdateType.ui, {"2"});
      }).catchError((e, s) {
        Logger.warn('Failed to get initial position: $e\n$s');
      });
    } catch (e, s) {
      if (e is! String) {
        Logger.warn('Failed to initialize geolocator: $e\n$s');
      }
    }
  }

  static Future<void> initializeTemporary() async {
    await initGeoLocator();

    String registeredUsers = prefs.getString('registered_users') ?? '[]';
    List<String> users;
    try {
      users = jsonDecode(registeredUsers).cast<String>();
    } catch (e) {
      users = [];
    }

    Set<String> toRemove = {};
    if (users.isNotEmpty) {
      for (var user in users) {
        Person? person = await db.personDao.getById(user);
        if (person != null) {
          localPersons[user] = person;
        } else {
          Logger.error('Person "$user" not found in database');
          toRemove.add(user);
        }
      }
    }

    if (toRemove.isNotEmpty) {
      for (var user in toRemove) {
        await logout(user.split(' ')[0]);
      }
    }

    if (localPersons.isEmpty) {
      while (true) {
        try {
          Globals.router.go('/login');
          break;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }
  }

  static bool initialized = false;
  static bool appStarted = false;
  static bool fastStartBypass = false;
  static bool foreground = false;

  static List<String> get registeredServers {
    String registeredUsers = Globals.prefs.getString('registered_users') ?? '[]';
    List<String> users;
    try {
      users = jsonDecode(registeredUsers).cast<String>();
    } catch (e) {
      users = [];
    }

    List<String> servers = [];
    for (String user in users) {
      String server = user.split(' ')[0];
      if (!servers.contains(server)) servers.add(server);
    }

    return servers;
  }

  static Map<String, Person> localPersons = {};
  static String? localPersonForServer(String server) {
    for (var person in localPersons.values) {
      if (person.server == server) {
        return person.id;
      }
    }
    return null;
  }

  static Position? lastPosition;
  static DateTime? lastPositionTime;

  static StreamSubscription<Position>? positionSubscription;

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'alarm',
            builder: (BuildContext context, GoRouterState state) {
              final Alarm alarm = state.extra! as Alarm;
              return AlarmPage(alarm: alarm);
            },
          ),
          GoRoute(
            path: 'lifecycle',
            builder: (BuildContext context, GoRouterState state) => const LifeCycleSettings(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (BuildContext context, GoRouterState state) => const NotificationSettings(),
          ),
          GoRoute(
            path: 'alarmsettings',
            builder: (BuildContext context, GoRouterState state) {
              final String stationId = state.extra! as String;
              return SettingsAlarmInformationPage(stationId: stationId);
            },
          ),
          GoRoute(
            path: 'login',
            onExit: (BuildContext context) {
              return Globals.localPersons.isNotEmpty;
            },
            builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
          ),
        ],
      ),
    ],
  );
}
