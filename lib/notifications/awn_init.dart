import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/globals.dart';

Future<void> initializeAwesomeNotifications() async {
  await AwesomeNotifications().removeChannel('test');
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
      // TODO, one for tests, one for each alarm section (station + vehicle identifier)
    ],
  );

  // TODO request permission for:
  // - notifications (sound, vibration, alert)
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

  // - ignore Do Not Disturb
  // TODO

  // - ignore battery optimization
  // TODO
}

@pragma('vm:entry-point')
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  Globals.fastStartBypass = true;
}

Future<bool> sendTestAlarm() async {
  try {
    return await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'test',
        title: 'Testalarm',
        body: 'Dies ist eine Testalarmierung',
        wakeUpScreen: true,
        category: NotificationCategory.Call,
        customSound: 'resource://raw/res_alarm',
        displayOnBackground: true,
        displayOnForeground: true,
        criticalAlert: true,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'test_accept',
          label: 'Annehmen',
          enabled: true,
          actionType: ActionType.Default,
          isAuthenticationRequired: true,
          showInCompactView: true,
        ),
        NotificationActionButton(
          key: 'test_decline',
          label: 'Ablehnen',
          enabled: true,
          actionType: ActionType.SilentAction,
          isAuthenticationRequired: true,
          showInCompactView: true,
        ),
      ],
    );
  } catch (e) {
    print('Failed to send test alarm: $e');
    return false;
  }
}
