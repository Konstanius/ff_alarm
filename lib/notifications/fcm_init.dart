import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/ui/popups/alarm_info.dart';
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
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
      Logger.ok('FCM token: $token');
    }
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  firebaseMessagingHandler(message, false);
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingHandler(RemoteMessage message, bool foreground) async {
  Logger.fcm('FCM message received: ${message.data}');
  WidgetsFlutterBinding.ensureInitialized();
  await Globals.initialize(true);

  Map<String, dynamic> data = message.data;

  String type = data['type'];

  switch (type) {
    case "alarm":
      {
        Alarm alarm = Alarm.inflateFromString(data['alarm']);
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 100));
          UpdateInfo(UpdateType.alarm, {alarm.id});
          return; // handled by the app extension
        }

        Alarm? existing = await Globals.db.alarmDao.getById(alarm.id);
        if (existing != null && existing.date.isAfter(alarm.date)) {
          Logger.warn('Received outdated alarm: $alarm');
          return;
        }
        await Alarm.update(alarm, true);

        bool shouldNotify = await SettingsNotificationData.shouldNotifyForAlarmRegardless(alarm);
        AlarmOption option = await alarm.getAlertOption(shouldNotify);

        await sendAlarm(alarm, option);

        if (alarm.type.startsWith('Test') || alarm.responseTimeExpired) return;

        try {
          var fetched = await AlarmInterface.fetchSingle(alarm.server, alarm.idNumber);

          var ownResponse = fetched.ownResponse;
          if ((ownResponse == null || ownResponse.getResponseInfo().responseType == AlarmResponseType.notSet) && !shouldNotify) {
            await AlarmInterface.setResponse(
              server: alarm.server,
              alarmId: alarm.idNumber,
              responseType: AlarmResponseType.notReady,
              stationId: null,
              note: '',
            );
          }
        } catch (e, s) {
          Logger.error('Failed to fetch single alarm: $e\n$s');
        }
        break;
      }
  }
}
