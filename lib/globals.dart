import 'dart:io';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:ff_alarm/data/prefs.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

abstract class Globals {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static bool initialized = false;
  static late final String filesPath;
  static late final String cachePath;
  static late final Prefs prefs;

  static bool loggedIn = false;

  static Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    if (!Platform.isIOS) {
      filesPath = (await getApplicationSupportDirectory()).path;
    } else {
      // Since we are trying to share resources with the app extension, we need to use the group directory
      filesPath = (await AppGroupDirectory.getAppGroupDirectory('group.de.jena.feuerwehr.app'))!.path;
    }
    cachePath = (await getTemporaryDirectory()).path;

    prefs = Prefs(identifier: 'main');
  }

  static bool appStarted = false;
  static bool fastStartBypass = false;

  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
      ),
    ],
  );

  static const bool sslAllowance = false;
  static const String connectionAddress = '192.168.178.89:443';
  static const String devPrefix = '';
}
