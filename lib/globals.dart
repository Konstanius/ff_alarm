import 'dart:io';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/data/prefs.dart';
import 'package:ff_alarm/ui/alarm_info.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

abstract class Globals {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static bool initialized = false;
  static late final String filesPath;
  static late final String cachePath;
  static late final Prefs prefs;
  static late final Isar db;

  static bool loggedIn = false;

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

    db = await Isar.open(
      [StationSchema, UnitSchema, PersonSchema, AlarmSchema],
      directory: '$filesPath/isar',
      name: 'main.isar',
      inspector: false,
    );
  }

  static bool appStarted = false;
  static bool fastStartBypass = false;

  static final GoRouter router = GoRouter(
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
        ],
      ),
    ],
  );

  static const bool sslAllowance = false;
  static const String connectionAddress = '192.168.178.89:443';
}
