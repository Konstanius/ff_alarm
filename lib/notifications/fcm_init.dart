import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import '../firebase_options.dart';
import 'dart:io';

Future<void> initializeFirebaseMessaging() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
  if (Platform.isIOS) return; // handled by the app extension
  WidgetsFlutterBinding.ensureInitialized();
  await Globals.initialize();

  Map<String, dynamic> data = message.data;

  String type = data['type'];

  switch (type) {
    case "alarm":
      {
        Alarm alarm = Alarm.inflateFromString(data['alarm']);
        await Globals.db.alarmDao.inserts(alarm);

        int lastAlarmTime = Globals.prefs.getInt('last_alarm_time') ?? 0;
        if (alarm.date.millisecondsSinceEpoch > lastAlarmTime) {
          Globals.prefs.setInt('last_alarm_id', alarm.id);
          Globals.prefs.setInt('last_alarm_time', alarm.date.millisecondsSinceEpoch);
        }

        if (alarm.id == 0) {
          await sendAlarm(alarm);
          return;
        }

        // await sendAlarm(alarm);
        break;
      }
  }
}
