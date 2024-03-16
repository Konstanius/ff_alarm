import 'dart:async';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/notifications/fcm_init.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.red('PlatformDispatcher error: $error\n$stack');
    return true;
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Globals.initialize();
    if (!Globals.fastStartBypass) {
      try {
        await initializeAwesomeNotifications();
      } catch (e, s) {
        Logger.red('Failed to initialize awesome_notifications: $e\n$s');
      }
      try {
        await initializeFirebaseMessaging();
      } catch (e, s) {
        Logger.red('Failed to initialize firebase_messaging: $e\n$s');
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      firebaseMessagingHandler(message, true);
    });

    // TODO logged in check

    // lock to portrait mode
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);

    [
      Permission.ignoreBatteryOptimizations,
      Permission.scheduleExactAlarm,
    ].request().then((result) {
      for (Permission permission in result.keys) {
        print('Permission ${permission.toString()}: ${result[permission]}');
      }
    });

    Globals.prefs.setInt('auth_user', 1);
    Globals.prefs.setString('auth_token', 'abcdefgh');
    Globals.loggedIn = true;

    runApp(const FFAlarmApp());
  }, (error, stack) {
    if (error is AckError) {
      Logger.yellow('runZonedGuarded error: ${error.errorCode}, ${error.errorMessage}');
      return;
    }
    Logger.red('runZonedGuarded error: $error\n$stack');
  });
}
