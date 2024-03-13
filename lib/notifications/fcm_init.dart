import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import '../firebase_options.dart';

Future<void> initializeFirebaseMessaging() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    firebaseMessagingHandler(message, true);
  });

  // get token here if not gotten yet
  FirebaseMessaging.instance.getToken().then((String? token) {
    if (token != null) {
      Globals.prefs.setString('fcm_token', token);
      Logger.green('FCM token: $token');
    }
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  firebaseMessagingHandler(message, false);
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingHandler(RemoteMessage message, bool foreground) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Globals.initialize();

  await sendTestAlarm();
}
