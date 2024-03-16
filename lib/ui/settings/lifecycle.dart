import 'dart:async';
import 'dart:io';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LifeCycleSettings extends StatefulWidget {
  const LifeCycleSettings({super.key});

  @override
  State<LifeCycleSettings> createState() => _LifeCycleSettingsState();
}

class _LifeCycleSettingsState extends State<LifeCycleSettings> {
  bool ignoreBatteryOptimizations = false;
  bool locationWhenInUse = false;
  bool locationAlways = false;
  bool appOptimizations = false;
  bool backgroundActivity = false;
  bool allowAutoLaunch = false;
  bool backgroundData = false;

  late Timer _timer;

  Future<void> checkSettings() async {
    locationWhenInUse = await Permission.locationWhenInUse.isGranted;
    locationAlways = await Permission.locationAlways.isGranted;

    if (Platform.isAndroid) {
      ignoreBatteryOptimizations = await Permission.ignoreBatteryOptimizations.isGranted;
      // TODO: backgroundActivity, allowAutoLaunch

      try {
        final result = await Globals.channel.invokeMethod('backgroundData');
        backgroundData = result as bool;
      } catch (e) {
        Logger.error('Failed to get backgroundData: $e');
        backgroundData = false;
      }

      appOptimizations = Globals.prefs.getBool('appOptimizations') ?? false;
    }

    if (mounted) setState(() {});
  }

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
        title: const Text('App Optimierungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: Center(
                    child: Divider(
                      color: Colors.blue,
                      thickness: 1.5,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    color: Theme.of(context).colorScheme.background,
                    child: Text(
                      '  Funktionsnotwendig!  ',
                      style: Theme.of(context).textTheme.subtitle1!.copyWith(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Permission ignoreBatteryOptimizations
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.battery_unknown_outlined),
              title: const Text('Akkuoptimierungen ignorieren'),
              subtitle: ignoreBatteryOptimizations ? const Text('Akkuoptimierungen für diese App deaktiviert.') : const Text('Akkuoptimierungen für diese App aktiviert.'),
              trailing: ignoreBatteryOptimizations ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.close, color: Colors.red),
              onTap: () async {
                if (ignoreBatteryOptimizations) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Akkuoptimierungen ignorieren',
                  content: const Text(
                    'Durch das Ignorieren der Akkuoptimierungen wird die App nicht mehr automatisch beendet und kann im Hintergrund weiterlaufen.\n\n'
                    'Dies kann Probleme in der Alarmierungs- und Standortbestimmungsfunktion beheben, aber auch die Akkulaufzeit beeinträchtigen.',
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

                var result = await Permission.ignoreBatteryOptimizations.request();
                if (result.isGranted) {
                  successToast('Einstellung erfolgreich!');
                } else {
                  errorToast('Einstellung fehlgeschlagen!');
                }

                checkSettings();
              },
            ),

          if (Platform.isAndroid) ...[
            // disable remove permissions if app isn't used / disable pause activity if app isn't used
            ListTile(
              leading: const Icon(Icons.remove_moderator_outlined),
              title: const Text('App-Optimierungen'),
              subtitle: const Text('Verhindert, dass Berechtigungen bei Inaktivität entfernt werden.'),
              trailing: appOptimizations ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.close, color: Colors.red),
              onTap: () async {
                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'App-Optimierungen',
                  content: const Text(
                    'Durch das Deaktivieren der App-Optimierungen wird verhindert, dass Berechtigungen bei Inaktivität von Android entfernt werden.\n\n'
                    'Dies ist notwendig, damit die App über längere Zeit funktionstüchtig bleibt und Alarmierungen zuverlässig empfangen werden können.\n\n'
                    'Beim Fortfahren musst du in der folgenden Seite erst auf "Berechtigungen" klicken, dann ganz unten die Einstellung "Berechtigungen bei Nicht-Nutzung entfernen" (oder Ähnlich) deaktivieren.',
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

                openAppSettings();

                await Future.delayed(const Duration(seconds: 1));

                var result = await generalDialog(
                  color: Colors.blue,
                  title: 'App-Optimierungen',
                  content: const Text(
                    'Hast du die Einstellung "Berechtigungen bei Nicht-Nutzung entfernen" (oder Ähnlich) deaktiviert?',
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
                  Globals.prefs.setBool('appOptimizations', true);
                  successToast('Einstellung erfolgreich!');
                } else {
                  Globals.prefs.remove('appOptimizations');
                  errorToast('Einstellung fehlgeschlagen!');
                }

                checkSettings();
              },
            ),
            // background data
            ListTile(
              leading: const Icon(Icons.data_usage_outlined),
              title: const Text('Hintergrunddaten'),
              subtitle: backgroundData ? const Text('Hintergrunddaten für diese App aktiviert.') : const Text('Hintergrunddaten für diese App deaktiviert.'),
              trailing: backgroundData ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.close, color: Colors.red),
              onTap: () async {
                if (backgroundData) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Hintergrunddaten',
                  content: const Text(
                    'Durch das Aktivieren der Hintergrunddaten wird die App auch im Hintergrund weiterhin auf das Internet zugreifen können.\n\n'
                    'Dies ist notwendig, wenn du bei einer Alarmierung auch im Hintergrund auf dem Laufenden gehalten werden möchtest.\n\n'
                    'Beim Fortfahren musst du in der folgenden Seite die Datennutzungsdetails öffnen und Hintergrunddaten erlauben.',
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

                openAppSettings();
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: Center(
                      child: Divider(
                        color: Colors.blue,
                        thickness: 1.5,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      color: Theme.of(context).colorScheme.background,
                      child: Text(
                        '  Optional, aber empfohlen!  ',
                        style: Theme.of(context).textTheme.subtitle1!.copyWith(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // battery usage -> background activity
            ListTile(
              leading: const Icon(Icons.phonelink),
              title: const Text('Hintergrundaktivität'),
              subtitle: const Text('Erlaubt der App, im Hintergrund weiterzulaufen.'),
              trailing: backgroundActivity ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.warning, color: Colors.amber),
              onTap: () {
                if (backgroundActivity) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }
                // TODO redirect to battery settings
                checkSettings();
              },
            ),
            // battery usage -> allow auto launch
            ListTile(
              leading: const Icon(Icons.restart_alt_outlined),
              title: const Text('Automatischer Start'),
              subtitle: const Text('Erlaubt der App, sich und seine Dienste von selbst zu starten.'),
              trailing: allowAutoLaunch ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.warning, color: Colors.amber),
              onTap: () {
                if (allowAutoLaunch) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }
                // TODO redirect to battery settings
                checkSettings();
              },
            ),
          ],

          // Permission locationWhenInUse and locationAlways
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Standortzugriff'),
            subtitle: () {
              if (locationAlways) return const Text('Standortzugriff immer erlaubt.');
              if (locationWhenInUse) return const Text('Standortzugriff nur bei App-Nutzung erlaubt.');
              return const Text('Standortzugriff nie erlaubt.');
            }(),
            trailing: () {
              if (locationAlways && locationWhenInUse) return const Icon(Icons.check, color: Colors.green);
              return const Icon(Icons.warning, color: Colors.amber);
            }(),
            onTap: () async {
              if (locationAlways) {
                infoToast('Einstellung bereits aktiviert!');
                return;
              }

              var result = await Permission.locationWhenInUse.request();
              if (result.isGranted) {
                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Standortzugriff',
                  content: const Text(
                    'Durch das Aktivieren des dauerhaften Standortzugriffs wird FF Alarm auch im Hintergrund auf deinen Standort zugreifen können.\n\n'
                    'Dies ist notwendig, wenn du bei einer Alarmierung bei anderen Kameraden live auf der Karte angezeigt werden sollst.\n\n'
                    'Beim Fortfahren musst du in der folgenden Seite den Standortzugriff auf "Immer erlauben" setzen.',
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
                if (res != true) {
                  checkSettings();
                  return;
                }

                result = await Permission.locationAlways.request();
              }
              if (result.isGranted) {
                successToast('Einstellung erfolgreich!');
              } else {
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
