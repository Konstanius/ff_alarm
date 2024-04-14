import 'dart:async';
import 'dart:io';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LifeCycleSettings extends StatefulWidget {
  const LifeCycleSettings({super.key});

  @override
  State<LifeCycleSettings> createState() => LifeCycleSettingsState();
}

class LifeCycleSettingsState extends State<LifeCycleSettings> {
  bool ignoreBatteryOptimizations = false;
  bool locationWhenInUse = false;
  bool locationAlways = false;
  bool motionSensors = false;
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
      motionSensors = true;

      try {
        final result = await Globals.channel.invokeMethod('backgroundData');
        backgroundData = result as bool;
      } catch (e) {
        Logger.error('Failed to get backgroundData: $e');
        backgroundData = false;
      }

      appOptimizations = Globals.prefs.getBool('appOptimizations') ?? false;
      backgroundActivity = Globals.prefs.getBool('backgroundActivity') ?? false;
      allowAutoLaunch = Globals.prefs.getBool('allowAutoLaunch') ?? false;
    } else {
      motionSensors = await Permission.sensors.isGranted;
    }

    UpdateInfo(UpdateType.ui, {"1"});

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    checkSettings();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      bool locationAlwaysPreviously = locationAlways;
      checkSettings();
      if (locationAlways != locationAlwaysPreviously) {
        Globals.initGeoLocator();
        if (locationAlways) {
          successToast('Standortzugriff aktiviert!');
        } else {
          errorToast('Standortzugriff deaktiviert!');
        }
      }
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
          if (Platform.isAndroid) ...[
            const SettingsDivider(text: 'Funktionsnotwendig'),
            // ignoreBatteryOptimizations
            ListTile(
              leading: const Icon(Icons.battery_unknown_outlined),
              title: const Text('Akkuoptimierungen ignorieren'),
              subtitle: const Text('Erlaubt der App, im Hintergrund weiterzulaufen.'),
              trailing: ignoreBatteryOptimizations ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.close_outlined, color: Colors.red),
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
            // disable remove permissions if app isn't used / disable pause activity if app isn't used
            ListTile(
              leading: const Icon(Icons.remove_moderator_outlined),
              title: const Text('App-Optimierungen'),
              subtitle: const Text('Verhindert, dass Berechtigungen bei Inaktivität entfernt werden.'),
              trailing: appOptimizations ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.close_outlined, color: Colors.red),
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
            // backgroundData
            ListTile(
              leading: const Icon(Icons.data_usage_outlined),
              title: const Text('Hintergrunddaten'),
              subtitle: const Text('Erlaubt der App, im Hintergrund auf das Internet zuzugreifen.'),
              trailing: backgroundData ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.close_outlined, color: Colors.red),
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
            const SettingsDivider(text: 'Optional - Empfohlen'),
            // batteryUsage -> background activity
            ListTile(
              leading: const Icon(Icons.phonelink_outlined),
              title: const Text('Hintergrundaktivität'),
              subtitle: const Text('Erlaubt der App, im Hintergrund weiterzulaufen.'),
              trailing: backgroundActivity ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.warning_amber_outlined, color: Colors.amber),
              onTap: () async {
                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Hintergrundaktivität',
                  content: const Text(
                    'Durch das Aktivieren der Hintergrundaktivität wird die App auch im Hintergrund weiterlaufen können.\n\n'
                    'Dies ist notwendig, wenn du bei einer Alarmierung auch im Hintergrund auf dem Laufenden gehalten werden möchtest.\n\n'
                    'Beim Fortfahren musst du in der folgenden Seite die Batterienutzung öffnen und die Einstellung "Hintergrundaktivität" (oder Ähnlich) aktivieren.',
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
                  title: 'Hintergrundaktivität',
                  content: const Text(
                    'Hast du die Einstellung "Hintergrundaktivität" (oder Ähnlich) aktiviert?',
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
                  Globals.prefs.setBool('backgroundActivity', true);
                  successToast('Einstellung erfolgreich!');
                } else {
                  Globals.prefs.remove('backgroundActivity');
                  errorToast('Einstellung fehlgeschlagen!');
                }

                checkSettings();
              },
            ),
            // batteryUsage -> allow auto launch
            ListTile(
              leading: const Icon(Icons.restart_alt_outlined),
              title: const Text('Automatischer Start'),
              subtitle: const Text('Erlaubt der App, Sich und Seine Dienste von selbst zu starten.'),
              trailing: allowAutoLaunch ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.warning_amber_outlined, color: Colors.amber),
              onTap: () async {
                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Automatischer Start',
                  content: const Text(
                    'Durch das Aktivieren des automatischen Starts kann die App gestoppte Dienste von selbst starten können.\n\n'
                    'Dies ist notwendig, damit die App auch im Hintergrund weiterlaufen kann und Alarmierungen zuverlässig empfangen werden können.\n\n'
                    'Beim Fortfahren musst du in der folgenden Seite die Batterienutzung öffnen und die Einstellung "Automatischer Start" (oder Ähnlich) aktivieren.',
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
                  title: 'Automatischer Start',
                  content: const Text(
                    'Hast du die Einstellung "Automatischer Start" (oder Ähnlich) aktiviert?',
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
                  Globals.prefs.setBool('allowAutoLaunch', true);
                  successToast('Einstellung erfolgreich!');
                } else {
                  Globals.prefs.remove('allowAutoLaunch');
                  errorToast('Einstellung fehlgeschlagen!');
                }

                checkSettings();
              },
            ),
            const SettingsDivider(text: 'Optional'),
          ],
          // locationWhenInUse and locationAlways
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Standortzugriff'),
            subtitle: const Text('Erlaubt der App, auf deinen Standort zuzugreifen.'),
            trailing: () {
              if (locationAlways && locationWhenInUse) return const Icon(Icons.check_outlined, color: Colors.green);
              return const Icon(Icons.warning_amber_outlined, color: Colors.amber);
            }(),
            onTap: () async {
              if (locationAlways) {
                infoToast('Einstellung bereits aktiviert!');
                return;
              }

              await requestLocationPermission();
              checkSettings();
            },
          ),
          // motionSensors
          if (Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.motion_photos_on_outlined),
              title: const Text('Bewegungssensoren'),
              subtitle: const Text('Erlaubt der App, genauere Positionsabfragen zu stellen.'),
              trailing: motionSensors ? const Icon(Icons.check_outlined, color: Colors.green) : const Icon(Icons.warning_amber_outlined, color: Colors.amber),
              onTap: () async {
                if (motionSensors) {
                  infoToast('Einstellung bereits aktiviert!');
                  return;
                }

                var res = await generalDialog(
                  color: Colors.blue,
                  title: 'Bewegungssensoren',
                  content: const Text(
                    'Durch das Aktivieren der Bewegungssensoren kann die App genauere Positionsabfragen stellen.\n\n'
                    'Dies erlaubt dem Geofence Feature, genauer zu bestimmen, ob du dich in einem Alarmierungs-Gebiet befindest.',
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

                var result = await Permission.sensors.request();
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

  static Future<void> requestLocationPermission() async {
    if (Platform.isIOS) {
      // Tell the user that they need to select "When in use" in the first dialog, or else it will fail
      var res = await generalDialog(
        color: Colors.blue,
        title: 'Standortzugriff',
        content: const Text(
          'Durch das Aktivieren des Standortzugriffs wird FF Alarm deinen Standort auf Karten für dich anzeigen können.\n\n'
          'Klicke auf "Fortfahren" und wähle dann "Immer erlauben" aus.\n\n'
          '"Einmal erlauben" reicht nicht aus, da Du die Berechtigung sonst bei Inaktivität verlierst',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(Globals.context!, false);
            },
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(Globals.context!, true);
            },
            child: const Text('Fortfahren'),
          ),
        ],
      );
      if (res != true) return;
    }
    var result = await Permission.locationWhenInUse.request();
    if (result.isGranted) {
      var res = await generalDialog(
        color: Colors.blue,
        title: 'Standortzugriff',
        content: const Text(
          'Durch das Aktivieren des dauerhaften Standortzugriffs wird FF Alarm bei aktivierten Geofences im Hintergrund deinen Standort mit dem Server teilen.\n\n'
          'DEIN STANDORT WIRD NIEMALS MIT ANDEREN GETEILT ODER DAUERHAFT GESPEICHERT!\n\n'
          'Beim Fortfahren musst du in der folgenden Seite den Standortzugriff auf "Immer erlauben" setzen.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(Globals.context!, false);
            },
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(Globals.context!, true);
            },
            child: const Text('Fortfahren'),
          ),
        ],
      );
      if (res != true) {
        return;
      }

      result = await Permission.locationAlways.request();
    }
  }
}
