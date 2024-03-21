import 'dart:async';
import 'dart:io';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:ff_alarm/data/database.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/prefs.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:ff_alarm/ui/popups/alarm_info.dart';
import 'package:ff_alarm/ui/popups/login_screen.dart';
import 'package:ff_alarm/ui/settings/lifecycle.dart';
import 'package:ff_alarm/ui/settings/notifications.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/cupertino.dart';
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

  static Future<void> initializeTemporary() async {
    try {
      // check if permission is granted, else throw
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location service is disabled');
      }

      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        throw Exception('Location permission is denied');
      }

      positionSubscription = Geolocator.getPositionStream().listen((Position position) {
        lastPosition = position;
        lastPositionTime = DateTime.now();
        UpdateInfo(UpdateType.ui, {2});
      });

      // get initial position
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 5)).then((Position? position) {
        lastPosition = position;
        lastPositionTime = DateTime.now();
        UpdateInfo(UpdateType.ui, {2});
      }).catchError((e, s) {
        Logger.warn('Failed to get initial position: $e\n$s');
      });
    } catch (e, s) {
      Logger.warn('Failed to initialize geolocator: $e\n$s');
    }

    int? userId = Globals.prefs.getInt('auth_user');
    String? token = Globals.prefs.getString('auth_token');
    String? connectionAddress = Globals.prefs.getString('connection_address');
    if (userId != null && token != null && connectionAddress != null) {
      Person? person = await Globals.db.personDao.getById(userId);
      if (person != null) {
        Globals.loggedIn = true;
        Globals.person = person;
        Globals.connectionAddress = connectionAddress;
      } else {
        Globals.loggedIn = false;
        Globals.prefs.remove('auth_user');
        Globals.prefs.remove('auth_token');
      }
    } else {
      Globals.loggedIn = false;
      Globals.prefs.remove('auth_user');
      Globals.prefs.remove('auth_token');
    }
  }

  static bool initialized = false;
  static bool appStarted = false;
  static bool fastStartBypass = false;
  static bool foreground = false;
  static bool loggedIn = false;

  static Person? person;

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
            path: 'login',
            onExit: (BuildContext context) {
              return Globals.loggedIn;
            },
            builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
          ),
        ],
      ),
    ],
  );

  static String connectionAddress = '://192.168.178.89:443';
}
