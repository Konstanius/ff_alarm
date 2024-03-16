import 'dart:async';
import 'dart:io';

import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  bool notifications = false;
  bool scheduleExactAlarm = false;
  bool accessNotificationPolicy = false;
  bool criticalAlerts = false;

  Future<void> checkSettings() async {
    notifications = await Permission.notification.isGranted;
    if (Platform.isAndroid) {
      scheduleExactAlarm = await Permission.scheduleExactAlarm.isGranted;
      accessNotificationPolicy = await Permission.accessNotificationPolicy.isGranted;
    }

    if (Platform.isIOS) {
      criticalAlerts = await Permission.criticalAlerts.isGranted;
    }

    if (mounted) setState(() {});
  }

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    checkSettings();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      checkSettings();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benachrichtigungseinstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Permission notification
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Benachrichtigungen'),
            subtitle: notifications ? const Text('Benachrichtigungen für diese App sind aktiviert.') : const Text('Benachrichtigungen für diese App sind deaktiviert.'),
            trailing: notifications ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.close, color: Colors.red),
            onTap: () async {
              if (notifications) {
                infoToast('Einstellung bereits aktiviert!');
                return;
              }

              final status = await Permission.notification.request();
              if (status.isGranted) {
                successToast('Einstellung aktiviert!');
              } else {
                errorToast('Einstellung fehlgeschlagen!');
              }
              checkSettings();
            },
          ),

          // Permission criticalAlerts
          if (Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('Kritische Alarme'),
              subtitle: criticalAlerts ? const Text('Kritische Alarme ist für diese App aktiviert.') : const Text('Kritische Alarme ist für diese App deaktiviert.'),
              trailing: criticalAlerts ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.warning, color: Colors.red),
              onTap: () async {
                if (criticalAlerts) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Kritische Alarme',
                  content: const Text(
                    'Diese Einstellung ermöglicht es der App, den "Nich stören"-Modus zu umgehen und Alarmierungen auch bei komplett stummgeschaltetem Gerät zu empfangen und laut zu signalisieren.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Fortfahren'),
                    ),
                  ],
                );
                if (res != true) return;

                final status = await Permission.criticalAlerts.request();
                if (status.isGranted) {
                  successToast('Einstellung aktiviert!');
                } else {
                  errorToast('Einstellung fehlgeschlagen!');
                }
                checkSettings();
              },
            ),

          // Permission scheduleExactAlarm
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Genauer Alarm'),
              subtitle: scheduleExactAlarm ? const Text('Genauer Alarm ist für diese App aktiviert.') : const Text('Genauer Alarm ist für diese App deaktiviert.'),
              trailing: scheduleExactAlarm ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.warning, color: Colors.red),
              onTap: () async {
                if (scheduleExactAlarm) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Genauer Alarm',
                  content: const Text(
                    'Diese Einstellung ermöglicht es der App, Benachrichtigungen ohne Verzögerung anzuzeigen.\n\n'
                    'Dadurch können Alarmierungen schneller und zuverlässiger empfangen werden.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Fortfahren'),
                    ),
                  ],
                );
                if (res != true) return;

                final status = await Permission.scheduleExactAlarm.request();
                if (status.isGranted) {
                  successToast('Einstellung aktiviert!');
                } else {
                  errorToast('Einstellung fehlgeschlagen!');
                }
                checkSettings();
              },
            ),
          // Permission accessNotificationPolicy
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.policy),
              title: const Text('Benachrichtigungspolitik'),
              subtitle: accessNotificationPolicy ? const Text('Benachrichtigungspolitik ist für diese App aktiviert.') : const Text('Benachrichtigungspolitik ist für diese App deaktiviert.'),
              trailing: accessNotificationPolicy ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.warning, color: Colors.red),
              onTap: () async {
                if (accessNotificationPolicy) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Nachrichtenverwaltung',
                  content: const Text(
                    'Diese Einstellung ermöglicht es der App, Alarmierungen auch bei stummgeschaltetem Gerät zu empfangen und laut zu signalisieren.\n\n'
                    'Der "Nicht Stören"-Modus kann weiterhin Alarmierungen verhindern, außer du deaktivierst Diesen unten.\n\n'
                    'Beim Fortfahren musst du in der folgenden Liste für die App "FF Alarm" die Benachrichtigungspolitik für den "Nicht-Stören"-Modus aktivieren.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Fortfahren'),
                    ),
                  ],
                );
                if (res != true) return;

                final status = await Permission.accessNotificationPolicy.request();
                if (status.isGranted) {
                  successToast('Einstellung aktiviert!');
                } else {
                  errorToast('Einstellung fehlgeschlagen!');
                }
                checkSettings();
              },
            ),

          // TODO check if Do Not Disturb override is enabled for notification channel "alarm"
        ],
      ),
    );
  }
}
