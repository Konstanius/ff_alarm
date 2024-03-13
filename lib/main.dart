import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/notifications/fcm_init.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // TODO logged in check

  // lock to portrait mode
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);

  runApp(const FFAlarmApp());
}
