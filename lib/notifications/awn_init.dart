import 'dart:convert';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:flutter/material.dart';

Future<void> initializeAwesomeNotifications() async {
  List<Station> stations = await Globals.db.stationDao.getAll();

  await AwesomeNotifications().initialize(
    null,
    <NotificationChannel>[
      NotificationChannel(
        channelKey: 'test',
        channelName: 'Test Alarmierungen',
        channelDescription: 'Benachrichtigungskanal für regelmäßige Testalarmierungen',
        channelShowBadge: true,
        criticalAlerts: true,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
        enableVibration: true,
        enableLights: true,
        importance: NotificationImportance.Max,
        soundSource: 'resource://raw/res_alarm',
      ),
      NotificationChannel(
        channelKey: 'test_silent',
        channelName: 'Test Alarmierungen (verpasst)',
        channelDescription: 'Benachrichtigungskanal für regelmäßige, verpasste, Testalarmierungen',
        channelShowBadge: true,
        criticalAlerts: false,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        enableVibration: true,
        enableLights: false,
        importance: NotificationImportance.Default,
        soundSource: null,
      ),
      NotificationChannel(
        channelKey: 'station_fallback',
        channelName: 'Redundanz-Alarmierungen',
        channelDescription: 'Benachrichtigungskanal für Alarmierungen, für die keine Station zugeordnet ist',
        channelShowBadge: true,
        criticalAlerts: true,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
        enableVibration: true,
        enableLights: true,
        importance: NotificationImportance.Max,
        soundSource: 'resource://raw/res_alarm',
      ),
      NotificationChannel(
        channelKey: 'station_fallback_silent',
        channelName: 'Redundanz-Alarmierungen (verpasst)',
        channelDescription: 'Benachrichtigungskanal für verpasste Alarmierungen, für die keine Station zugeordnet ist',
        channelShowBadge: true,
        criticalAlerts: false,
        defaultPrivacy: NotificationPrivacy.Public,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        enableVibration: true,
        enableLights: false,
        importance: NotificationImportance.Default,
        soundSource: null,
      ),
      for (Station station in stations) ...[
        NotificationChannel(
          channelKey: 'station_${station.name.toLowerCase()}',
          channelName: 'Alarmierungen für ${station.name}',
          channelDescription: 'Benachrichtigungskanal für Alarmierungen der Feuerwehr ${station.name}',
          channelShowBadge: true,
          criticalAlerts: true,
          defaultPrivacy: NotificationPrivacy.Public,
          defaultRingtoneType: DefaultRingtoneType.Ringtone,
          enableVibration: true,
          enableLights: true,
          importance: NotificationImportance.Max,
          soundSource: 'resource://raw/res_alarm',
        ),
        NotificationChannel(
          channelKey: 'station_${station.name.toLowerCase()}_silent',
          channelName: 'Alarmierungen für ${station.name} (verpasst)',
          channelDescription: 'Benachrichtigungskanal für verpasste Alarmierungen der Feuerwehr ${station.name}',
          channelShowBadge: true,
          criticalAlerts: false,
          defaultPrivacy: NotificationPrivacy.Public,
          defaultRingtoneType: DefaultRingtoneType.Notification,
          enableVibration: true,
          enableLights: false,
          importance: NotificationImportance.Default,
          soundSource: null,
        ),
      ],
    ],
  );

  bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    bool? neverAskAgain = Globals.prefs.getBool('notifications_never-ask-again');
    if (neverAskAgain != true) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        permissions: const [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.CriticalAlert,
          NotificationPermission.Vibration,
          NotificationPermission.FullScreenIntent,
        ],
      );
    }
  }

  AwesomeNotifications().setListeners(onActionReceivedMethod: onActionReceivedMethod);
}

@pragma('vm:entry-point')
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  Globals.fastStartBypass = true;

  String actionKey = receivedAction.buttonKeyPressed;
  Map<String, String?> payload = receivedAction.payload ?? {};

  String type = payload['type'] ?? '';
  if (type.isEmpty) return;

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
        Alarm alarm = Alarm.fromJson(jsonDecode(payload['alarm']!));
        if (Globals.router.routeInformationProvider.value.uri.pathSegments.lastOrNull != 'alarm') {
          Globals.router.go('/alarm', extra: alarm);
        } else if (Globals.router.routeInformationProvider.value.uri.pathSegments.isNotEmpty) {}
        break;
      }
  }
}

Future<bool> sendAlarm(Alarm alarm) async {
  try {
    AlarmOption option = alarm.getAlertOption();

    if (Globals.appStarted && option == AlarmOption.alert) {
      Globals.router.go('/alarm', extra: alarm);
    }

    String channelKey;
    if (alarm.id == 0) {
      channelKey = option == AlarmOption.alert ? 'test' : 'test_silent';
    } else {
      List<Unit> units = await Globals.db.unitDao.getAll();
      units = units.where((unit) => alarm.units.contains(unit.id)).toList();

      List<Station> stations = await Globals.db.stationDao.getAll();

      if (stations.isNotEmpty) {
        // sort by higher priority given to stations (priority is nullable, so all nulls are at the end)
        stations.sort((a, b) => (b.priority ?? 0).compareTo(a.priority ?? 0));

        String stationName = stations.first.name;
        channelKey = option == AlarmOption.alert ? 'station_${stationName.toLowerCase()}' : 'station_${stationName.toLowerCase()}_silent';
      } else {
        channelKey = option == AlarmOption.alert ? 'station_fallback' : 'station_fallback_silent';
      }
    }

    if (Platform.isAndroid) {}

    return await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: channelKey,
        title: alarm.type,
        body: alarm.word,
        category: option == AlarmOption.alert ? NotificationCategory.Call : NotificationCategory.Event,
        customSound: option == AlarmOption.alert ? 'resource://raw/res_alarm' : null,
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
        if (option == AlarmOption.alert)
          NotificationActionButton(
            key: 'alarm_click',
            label: 'Alarmierung ansehen',
            enabled: true,
            actionType: ActionType.Default,
            isAuthenticationRequired: false,
            showInCompactView: true,
            color: Colors.blue,
          ),
      ],
    );
  } catch (e) {
    print('Failed to send test alarm: $e');
    return false;
  }
}
