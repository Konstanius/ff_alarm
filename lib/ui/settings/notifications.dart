import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
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
  bool criticalAlertsTests = false;

  Future<void> checkSettings() async {
    notifications = await Permission.notification.isGranted;
    if (Platform.isAndroid) {
      scheduleExactAlarm = await Permission.scheduleExactAlarm.isGranted;
      accessNotificationPolicy = await Permission.accessNotificationPolicy.isGranted;
    }

    if (Platform.isIOS) {
      criticalAlerts = (await Globals.channel.invokeMethod('checkCriticalAlertPermission')) ?? false;
      criticalAlertsTests = false;
    } else if (Platform.isAndroid) {
      criticalAlerts = Globals.prefs.getBool('critical_alerts') ?? false;
      criticalAlertsTests = Globals.prefs.getBool('critical_alerts_test') ?? false;
    }

    UpdateInfo(UpdateType.ui, {"1"});

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
          const SettingsDivider(text: 'Funktionsnotwendig'),
          // notification
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Benachrichtigungen'),
            subtitle: const Text('Erlaubt der App, dir Benachrichtigungen anzuzeigen'),
            trailing: notifications ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.close_outlined, color: Colors.red),
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
          if (Platform.isAndroid)
            // scheduleExactAlarm
            ListTile(
              leading: const Icon(Icons.alarm_outlined),
              title: const Text('Genauer Alarm'),
              subtitle: const Text('Ermöglicht der App, Benachrichtigungen ohne Verzögerung anzuzeigen'),
              trailing: scheduleExactAlarm ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.close_outlined, color: Colors.red),
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
          if (Platform.isAndroid)
            // accessNotificationPolicy
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Benachrichtigungspolitik'),
              subtitle: const Text('Ermöglicht der App, Alarmierungen auch bei stummgeschaltetem Gerät zu empfangen und laut zu signalisieren'),
              trailing: accessNotificationPolicy ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.close_outlined, color: Colors.red),
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
                    'Der "Nicht-Stören"-Modus kann weiterhin Alarmierungen verhindern, außer du deaktivierst Diesen unten.\n\n'
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
          const SettingsDivider(text: 'Nicht-Stören-Modus'),
          if (Platform.isIOS)
            // criticalAlerts
            ListTile(
              leading: const Icon(Icons.warning_outlined),
              title: const Text('Kritische Alarme'),
              subtitle: const Text('Erlaubt der App, den "Nicht-Stören"-Modus zu umgehen'),
              trailing: criticalAlerts ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.warning_amber_outlined, color: Colors.amber),
              onTap: () async {
                if (criticalAlerts) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Kritische Alarme',
                  content: const Text(
                    'Diese Einstellung ermöglicht es der App, den "Nicht-Stören"-Modus zu umgehen und Alarmierungen auch bei komplett stummgeschaltetem Gerät zu empfangen und laut zu signalisieren.',
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

                // request via method channel from Globals
                final response = await Globals.channel.invokeMethod('requestCriticalAlertPermission');
                if (response == true) {
                  successToast('Einstellung aktiviert!');
                } else {
                  errorToast('Einstellung fehlgeschlagen!');
                }
                checkSettings();
              },
            ),
          if (Platform.isAndroid)
            // criticalAlerts
            ListTile(
              leading: const Icon(Icons.warning_outlined),
              title: const Text('Kritische Alarme'),
              subtitle: const Text('Erlaubt der App, den "Nicht-Stören"-Modus zu umgehen'),
              trailing: criticalAlerts ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.warning_amber_outlined, color: Colors.amber),
              onTap: () async {
                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Kritische Alarme',
                  content: const Text(
                    'Diese Einstellung ermöglicht es der App, den "Nich stören"-Modus zu umgehen und Alarmierungen auch bei komplett stummgeschaltetem Gerät zu empfangen und laut zu signalisieren.\n\n'
                    'Bitte aktiviere dazu in der folgenden Seite unten die Einstellung "Nicht-Stören"-Erlaubnis (oder Ähnlich).\n\n'
                    'Dies gilt NICHT für Test-Alarmierungen!',
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

                AwesomeNotifications().showNotificationConfigPage(channelKey: 'alarm');

                await Future.delayed(const Duration(seconds: 1));

                var result = await generalDialog(
                  color: Colors.blue,
                  title: 'Kritische Alarme',
                  content: const Text(
                    'Hast du die Einstellung für "Nicht-Stören"-Erlaubnis (oder Ähnlich) gefunden und aktiviert?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Nein'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Ja'),
                    ),
                  ],
                );

                if (result == true) {
                  Globals.prefs.setBool('critical_alerts', true);
                  successToast('Einstellung erfolgreich!');
                } else {
                  Globals.prefs.remove('critical_alerts');
                  errorToast('Einstellung fehlgeschlagen!');
                }

                checkSettings();
              },
            ),
          if (Platform.isAndroid)
            // criticalAlertsTest
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined),
              title: const Text('Kritische Alarme (Tests)'),
              subtitle: const Text('Erlaubt der App, den "Nicht-Stören"-Modus für Test-Alarmierungen zu umgehen'),
              trailing: criticalAlertsTests ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.warning_amber_outlined, color: Colors.amber),
              onTap: () async {
                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Kritische Alarme (Tests)',
                  content: const Text(
                    'Diese Einstellung ermöglicht es der App, den "Nich stören"-Modus zu umgehen und Test-Alarmierungen auch bei komplett stummgeschaltetem Gerät zu empfangen und laut zu signalisieren.\n\n'
                    'Bitte aktiviere dazu in der folgenden Seite unten die Einstellung "Nicht-Stören"-Erlaubnis (oder Ähnlich).\n\n'
                    'Dies gilt NUR für Test-Alarmierungen!',
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

                AwesomeNotifications().showNotificationConfigPage(channelKey: 'test');

                await Future.delayed(const Duration(seconds: 1));

                var result = await generalDialog(
                  color: Colors.blue,
                  title: 'Kritische Alarme',
                  content: const Text(
                    'Hast du die Einstellung für "Nicht-Stören"-Erlaubnis (oder Ähnlich) gefunden und aktiviert?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Nein'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Ja'),
                    ),
                  ],
                );

                if (result == true) {
                  Globals.prefs.setBool('critical_alerts_test', true);
                  successToast('Einstellung erfolgreich!');
                } else {
                  Globals.prefs.remove('critical_alerts_test');
                  errorToast('Einstellung fehlgeschlagen!');
                }

                checkSettings();
              },
            ),
        ],
      ),
    );
  }
}
