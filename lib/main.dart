import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/notifications/fcm_init.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Globals.initialize();
  if (!Globals.fastStartBypass) {
    try {
      await initializeAwesomeNotifications();
    } catch (e) {
      print('Failed to initialize awesome_notifications: $e');
      // TODO toast the user
    }
    try {
      await initializeFirebaseMessaging();
    } catch (e) {
      print('Failed to initialize firebase_messaging: $e');
      // TODO toast the user
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

  runApp(const FFAlarmApp());
}
