import 'dart:async';
import 'dart:convert';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/notifications/fcm_init.dart';
import 'package:ff_alarm/server/realtime.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.error('PlatformDispatcher error: $error\n$stack');
    return true;
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Globals.initialize();
    } catch (e, s) {
      Logger.error('Failed to initialize globals: $e\n$s');
      return;
    }

    if (!Globals.fastStartBypass) {
      try {
        await initializeAwesomeNotifications();
      } catch (e, s) {
        Logger.error('Failed to initialize awesome_notifications: $e\n$s');
      }

      try {
        await initializeFirebaseMessaging();
      } catch (e, s) {
        Logger.error('Failed to initialize firebase_messaging: $e\n$s');
      }
    }

    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        firebaseMessagingHandler(message, true);
      });
    } catch (e, s) {
      Logger.error('Failed to set up firebase messaging listeners: $e\n$s');
    }

    // lock to portrait mode
    try {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
    } catch (e, s) {
      Logger.error('Failed to lock to portrait mode: $e\n$s');
    }

    runApp(const FFAlarmApp());
  }, (error, stack) {
    if (error is AckError) {
      Logger.warn('runZonedGuarded error: ${error.errorCode}, ${error.errorMessage}');
      return;
    }
    Logger.error('runZonedGuarded error: $error\n$stack');
  });
}

Future<void> logout(String server) async {
  Logger.warn('Logging out from $server');

  Globals.prefs.remove('auth_user_$server');
  Globals.prefs.remove('auth_session_$server');
  Globals.prefs.remove('auth_token_$server');
  Globals.localPersons.removeWhere((key, value) => key.startsWith(server));

  String registeredUsers = Globals.prefs.getString('registered_users') ?? '[]';
  List<String> users;
  try {
    users = jsonDecode(registeredUsers).cast<String>();
  } catch (e) {
    users = [];
  }
  users.removeWhere((element) => element.startsWith("$server "));
  Globals.prefs.setString('registered_users', jsonEncode(users));

  try {
    await RealTimeListener.listeners[server]?.socket?.close();
  } catch (e, s) {
    Logger.error('Failed to disconnect socket: $e\n$s');
  }

  await Globals.db.alarmDao.deleteByPrefix("$server ");
  await Globals.db.personDao.deleteByPrefix("$server ");
  await Globals.db.stationDao.deleteByPrefix("$server ");
  await Globals.db.unitDao.deleteByPrefix("$server ");

  if (users.isEmpty) {
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
