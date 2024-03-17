import 'dart:async';
import 'dart:io';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:ff_alarm/data/database.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/prefs.dart';
import 'package:ff_alarm/ui/alarm/alarm_info.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:ff_alarm/ui/settings/lifecycle.dart';
import 'package:ff_alarm/ui/settings/notifications.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (initialized) return;
    initialized = true;
    if (!Platform.isIOS) {
      filesPath = (await getApplicationSupportDirectory()).path;
    } else {
      // Since we are trying to share assets with the app extension, we need to use the group directory
      filesPath = (await AppGroupDirectory.getAppGroupDirectory('group.de.jena.feuerwehr.app.ffAlarm'))!.path;
    }
    cachePath = (await getTemporaryDirectory()).path;

    prefs = Prefs(identifier: 'main');

    Directory dbDir = Directory('$filesPath/isar');
    if (!dbDir.existsSync()) {
      dbDir.createSync();
    }

    db = await $FloorAppDatabase.databaseBuilder('database.db').buildBetterPath();
  }

  static bool initialized = false;
  static bool appStarted = false;
  static bool fastStartBypass = false;
  static bool foreground = false;
  static bool loggedIn = false;

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
        ],
      ),
    ],
  );

  static const bool sslAllowance = false;
  static const String connectionAddress = '192.168.178.89:443';
}
