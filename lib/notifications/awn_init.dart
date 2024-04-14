import 'dart:convert';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:real_volume/real_volume.dart';

Future<void> initializeAwesomeNotifications() async {
  String? alarmSound = Globals.prefs.getString('alarm_soundPath');
  alarmSound ??= "res_alarm_1";

  await AwesomeNotifications().initialize(
    null,
    channelGroups: <NotificationChannelGroup>[
      NotificationChannelGroup(
        channelGroupKey: 'test',
        channelGroupName: 'Test Alarmierungen',
      ),
      NotificationChannelGroup(
        channelGroupKey: 'alarm',
        channelGroupName: 'Alarmierungen',
      ),
    ],
    <NotificationChannel>[
      NotificationChannel(
        channelKey: 'geofence',
        channelGroupKey: 'geofence',
        channelName: 'Geofence Service',
        channelDescription: 'Benachrichtigungskanal für Geofence-Alarmierungen',
        channelShowBadge: false,
        criticalAlerts: false,
        defaultPrivacy: NotificationPrivacy.Private,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        enableVibration: false,
        enableLights: false,
        importance: NotificationImportance.Min,
        locked: true,
      ),
      NotificationChannel(
        channelKey: 'test',
        channelGroupKey: 'test',
        channelName: 'Test Alarmierungen',
        channelDescription: 'Benachrichtigungskanal für regelmäßige Testalarmierungen',
        channelShowBadge: true,
        criticalAlerts: true,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
        enableVibration: true,
        enableLights: true,
        importance: NotificationImportance.High,
        soundSource: 'resource://raw/$alarmSound',
      ),
      NotificationChannel(
        channelKey: 'test_silent',
        channelGroupKey: 'test',
        channelName: 'Test Alarmierungen (stumm)',
        channelDescription: 'Benachrichtigungskanal für regelmäßige, stumme, Testalarmierungen',
        channelShowBadge: true,
        criticalAlerts: false,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        enableVibration: true,
        enableLights: false,
        importance: NotificationImportance.High,
        soundSource: null,
      ),
      NotificationChannel(
        channelKey: 'alarm',
        channelGroupKey: 'alarm',
        channelName: 'Alarmierungen',
        channelDescription: 'Benachrichtigungskanal für Alarmierungen',
        channelShowBadge: true,
        criticalAlerts: true,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
        enableVibration: true,
        enableLights: true,
        importance: NotificationImportance.High,
        soundSource: 'resource://raw/$alarmSound',
      ),
      NotificationChannel(
        channelKey: 'alarm_silent',
        channelGroupKey: 'alarm',
        channelName: 'Alarmierungen (stumm)',
        channelDescription: 'Benachrichtigungskanal für stumme Alarmierungen',
        channelShowBadge: true,
        criticalAlerts: false,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        enableVibration: true,
        enableLights: false,
        importance: NotificationImportance.High,
        soundSource: null,
      ),
    ],
  );

  AwesomeNotifications().setGlobalBadgeCounter(0);

  AwesomeNotifications().setListeners(onActionReceivedMethod: onActionReceivedMethod);
}

@pragma('vm:entry-point')
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  Logger.info('Received action: ${receivedAction.buttonKeyPressed}');
  Logger.info('Received payload: ${receivedAction.payload}');

  Globals.fastStartBypass = true;

  String actionKey = receivedAction.buttonKeyPressed;
  Map<String, String?> payload = receivedAction.payload ?? {};

  String type = payload['type'] ?? '';
  if (type.isEmpty) {
    Logger.error('Received action without type');
    return;
  }

  while (!Globals.appStarted) {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  if (actionKey.isEmpty) {
    switch (type) {
      case 'alarm':
        {
          Alarm alarm = Alarm.fromJson(jsonDecode(payload['alarm']!));
          if (Globals.router.routeInformationProvider.value.uri.pathSegments.lastOrNull != 'alarm') {
            Globals.router.go('/alarm', extra: alarm);
          } else if (Globals.router.routeInformationProvider.value.uri.pathSegments.isNotEmpty) {}
          break;
        }
    }
    return;
  }

  switch (actionKey) {
    case 'alarm_click':
      {
        resetAndroidNotificationVolume();
        Alarm alarm = Alarm.fromJson(jsonDecode(payload['alarm']!));
        if (Globals.router.routeInformationProvider.value.uri.pathSegments.lastOrNull != 'alarm') {
          Globals.router.go('/alarm', extra: alarm);
        } else if (Globals.router.routeInformationProvider.value.uri.pathSegments.isNotEmpty) {}
        break;
      }
  }
}

Future<void> resetAndroidNotificationVolume() async {
  if (!Platform.isAndroid) return;

  double? lastVolume = Globals.prefs.getDouble('last_volume');
  Globals.prefs.remove('last_volume');
  if (lastVolume != null) {
    try {
      await RealVolume.setVolume(lastVolume, streamType: StreamType.NOTIFICATION, showUI: false);
    } catch (e) {
      Logger.error('Failed to set volume: $e');
    }
  }

  int? lastMode = Globals.prefs.getInt('last_mode');
  Globals.prefs.remove('last_mode');
  if (lastMode != null) {
    try {
      await RealVolume.setRingerMode(RingerMode.values[lastMode]);
    } catch (e) {
      Logger.error('Failed to set mode: $e');
    }
  }
}

Future<bool> sendAlarm(Alarm alarm, AlarmOption option) async {
  try {

    if (Globals.appStarted && option == AlarmOption.alert) {
      Globals.router.go('/alarm', extra: alarm);
    }

    String channelKey;
    if (alarm.type.startsWith('Test')) {
      channelKey = option == AlarmOption.alert ? 'test' : 'test_silent';
    } else {
      channelKey = option == AlarmOption.alert ? 'alarm' : 'alarm_silent';
    }

    if (Platform.isAndroid && option == AlarmOption.alert) {
      try {
        try {
          double? volume = await RealVolume.getCurrentVol(StreamType.NOTIFICATION);
          RingerMode? mode = await RealVolume.getRingerMode();

          if (volume != null && mode != null) {
            Globals.prefs.setDouble('last_volume', volume);
            Globals.prefs.setInt('last_mode', mode.index);
          }
        } catch (e) {
          Logger.error('Failed to get volume: $e');
        }
        await RealVolume.setRingerMode(RingerMode.NORMAL);
        await RealVolume.setAudioMode(AudioMode.NORMAL);
        await RealVolume.setVolume(1.0, streamType: StreamType.NOTIFICATION, showUI: false);
      } catch (e) {
        Logger.error('Failed to set volume: $e');
      }
    }

    String? alarmSound = Globals.prefs.getString('alarm_soundPath');
    alarmSound ??= "res_alarm_1";

    return await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: alarm.idNumber,
        channelKey: channelKey,
        title: alarm.type,
        body: alarm.word,
        category: option == AlarmOption.alert ? NotificationCategory.Call : NotificationCategory.Event,
        customSound: option == AlarmOption.alert ? 'resource://raw/$alarmSound' : null,
        displayOnBackground: true,
        displayOnForeground: true,
        fullScreenIntent: true,
        wakeUpScreen: option == AlarmOption.alert,
        autoDismissible: option != AlarmOption.alert,
        locked: option == AlarmOption.alert,
        criticalAlert: option == AlarmOption.alert,
        payload: {
          'type': 'alarm',
          'alarm': jsonEncode(alarm.toJson()),
          'received': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'alarm_click',
          label: 'Alarmierung ansehen',
          enabled: true,
          actionType: ActionType.Default,
          isAuthenticationRequired: false,
          showInCompactView: true,
          autoDismissible: true,
          color: Colors.blue,
        ),
      ],
    );
  } catch (e) {
    Logger.error('Failed to send test alarm: $e');
    return false;
  }
}
