import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/main.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:real_volume/real_volume.dart';

import '../../log/logger.dart';
import '../utils/format.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.badge});

  final ValueNotifier<int> badge;

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin, Updates {
  @override
  bool get wantKeepAlive => true;

  int notificationsBad = 0;
  int lifeCycleBad = 0;

  List<Station>? stations;
  Map<String, SettingsNotificationData> allNotificationSettings = SettingsNotificationData.getAll();

  static Future<int> getBadNotificationsAmount() async {
    int notificationsBad = 0;

    try {
      var notifications = await Permission.notification.isGranted;
      if (!notifications) notificationsBad++;

      if (Platform.isAndroid) {
        var accessNotificationPolicy = await Permission.accessNotificationPolicy.isGranted;
        if (!accessNotificationPolicy) notificationsBad++;
      }

      return notificationsBad;
    } catch (e) {
      Logger.error('Failed to get bad notifications amount: $e');
      return 0;
    }
  }

  static Future<int> getBadLifeCycle() async {
    int lifeCycleBad = 0;
    if (Platform.isIOS) return lifeCycleBad;

    try {
      var ignoreBatteryOptimizations = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!ignoreBatteryOptimizations) lifeCycleBad++;

      var scheduleExactAlarm = await Permission.scheduleExactAlarm.isGranted;
      if (!scheduleExactAlarm) lifeCycleBad++;

      var appOptimizations = Globals.prefs.getBool('appOptimizations') ?? false;
      if (!appOptimizations) lifeCycleBad++;

      bool backgroundData;
      try {
        final result = await Globals.channel.invokeMethod('backgroundData');
        backgroundData = result as bool;
      } catch (e) {
        Logger.error('Failed to get backgroundData: $e');
        backgroundData = false;
      }
      if (!backgroundData) lifeCycleBad++;

      return lifeCycleBad;
    } catch (e) {
      Logger.error('Failed to get bad life cycle: $e');
      return 0;
    }
  }

  Future<void> checkSettings() async {
    notificationsBad = 0;
    lifeCycleBad = 0;

    notificationsBad = await getBadNotificationsAmount();
    lifeCycleBad = await getBadLifeCycle();

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    checkSettings();
    setupListener({UpdateType.ui, UpdateType.station});

    Station.getAll().then((value) {
      stations = value;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          const SettingsDivider(text: 'Daten-Quellen'),
          for (var localUser in Globals.localPersons.values)
            () {
              Uri uri;
              try {
                uri = Uri.parse('http${localUser.server}');
              } catch (e) {
                return const SizedBox.shrink();
              }

              return ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(uri.host),
                subtitle: Row(
                  children: [
                    if (localUser.server.startsWith('s')) ...[
                      const Icon(Icons.lock_outlined, color: Colors.green, size: kDefaultFontSize),
                      const SizedBox(width: 4),
                      const Text('Verschlüsselt'),
                    ] else ...[
                      const Icon(Icons.lock_person_outlined, color: Colors.red, size: kDefaultFontSize),
                      const SizedBox(width: 4),
                      const Text('Nicht verschlüsselt'),
                    ],
                  ],
                ),
                onTap: () async {
                  Globals.context!.loaderOverlay.show();

                  int stationsAmount = await Station.getAmount(localUser.server) ?? 0;
                  int alarmsAmount = await Alarm.getAmount(localUser.server) ?? 0;
                  int unitsAmount = await Unit.getAmount(localUser.server) ?? 0;
                  int personsAmount = await Person.getAmount(localUser.server) ?? 0;

                  Globals.context!.loaderOverlay.hide();

                  generalDialog(
                    color: Colors.blue,
                    title: 'Daten-Quelle',
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('Server'),
                          subtitle: Text(uri.host),
                        ),
                        ListTile(
                          title: const Text('Port'),
                          subtitle: Text(uri.port.toString()),
                        ),
                        ListTile(
                          title: const Text('SSL-Verschlüsselung'),
                          subtitle: Text(localUser.server.startsWith('s') ? 'Ja' : 'Nein'),
                        ),
                        ListTile(
                          title: const Text('Benutzer'),
                          subtitle: Text(localUser.fullName),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Wachen'),
                            Text(stationsAmount.toString()),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Einheiten'),
                            Text(unitsAmount.toString()),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Personen'),
                            Text(personsAmount.toString()),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Alarmierungen'),
                            Text(alarmsAmount.toString()),
                          ],
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('OK'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Globals.context!.loaderOverlay.show();
                          try {
                            bool connected = await Request.isConnected(localUser.server);
                            if (connected) {
                              successToast('Verbindung erfolgreich');
                            } else {
                              errorToast('Verbindung fehlgeschlagen');
                            }
                            Globals.context!.loaderOverlay.hide();
                          } catch (e, s) {
                            exceptionToast(e, s);
                            Globals.context!.loaderOverlay.hide();
                          }
                        },
                        child: const Text('Verbindung testen'),
                      ),
                    ],
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  style: ButtonStyle(minimumSize: MaterialStateProperty.all(Size.zero)),
                  onPressed: () {
                    generalDialog(
                      color: Colors.blue,
                      title: 'Quelle löschen',
                      content: Text('Möchtest Du die Daten-Quelle ${uri.host} wirklich löschen?\n\n'
                          'Alle Daten, die von dieser Quelle stammen, werden ebenfalls gelöscht.\n\n'
                          'Zur erneuten Registrierung musst Du von einem Wachen-Admin hinzugefügt werden.'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Abbrechen'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Globals.context!.loaderOverlay.show();
                            try {
                              var data = {
                                "sessionId": Globals.prefs.getInt('auth_session_${localUser.server}'),
                                "token": Globals.prefs.getString('auth_token_${localUser.server}'),
                                "fcmToken": "${Platform.isAndroid ? "A" : "I"}${Globals.prefs.getString('fcm_token')}",
                              };
                              await Request('logout', data, localUser.server).emit(true, guest: true);
                              Navigator.of(Globals.context!).pop();
                              await Future.delayed(const Duration(milliseconds: 20));
                              await logout(localUser.server);
                              Globals.context!.loaderOverlay.hide();
                            } catch (e, s) {
                              exceptionToast(e, s);
                              Globals.context!.loaderOverlay.hide();
                            }
                          },
                          child: const Text('Löschen'),
                        ),
                      ],
                    );
                  },
                ),
              );
            }(),
          ElevatedButton(
            onPressed: () {
              Globals.router.go('/login');
            },
            child: const Text('Daten-Quelle hinzufügen'),
          ),
          const SettingsDivider(text: 'App-Funktionalität'),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Optimierungen'),
            subtitle: lifeCycleBad > 0 ? Text('Aktion${lifeCycleBad > 1 ? 'en' : ''} erforderlich') : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lifeCycleBad > 0) const Icon(Icons.warning_outlined, color: Colors.red),
                const Icon(Icons.arrow_forward_outlined),
              ],
            ),
            onTap: () {
              Globals.router.push('/lifecycle');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Benachrichtigungen'),
            subtitle: notificationsBad > 0 ? Text('Aktion${notificationsBad > 1 ? 'en' : ''} erforderlich') : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (notificationsBad > 0) const Icon(Icons.warning_outlined, color: Colors.red),
                const Icon(Icons.arrow_forward_outlined),
              ],
            ),
            onTap: () {
              Globals.router.push('/notifications');
            },
          ),
          const SettingsDivider(text: 'Bereitschaft'),
          if (stations == null)
            const CircularProgressIndicator()
          else ...[
            for (var station in stations!)
              ListTile(
                leading: allNotificationSettings.containsKey(station.id) ? const Icon(Icons.settings_outlined) : const Icon(Icons.question_mark_outlined),
                title: Text("${station.name} (${station.prefix} ${station.area} ${station.stationNumber})"),
                subtitle: () {
                  LatLng? lastPosition;
                  if (Globals.lastPosition != null) {
                    lastPosition = Formats.positionToLatLng(Globals.lastPosition!);
                  }
                  if (allNotificationSettings.containsKey(station.id)) {
                    return Text(
                      'Zu deiner Position & Zeit:\n'
                      '${allNotificationSettings[station.id]!.shouldNotify(lastPosition) ? 'EINGESCHALTET' : 'STUMMGESCHALTET'}',
                    );
                  } else {
                    return const Text('Nicht konfiguriert');
                  }
                }(),
                trailing: const Icon(Icons.arrow_forward_outlined),
                onTap: () {
                  Globals.router.push('/alarmsettings', extra: station.id);
                },
              ),
          ],
          const SettingsDivider(text: 'Alarmierungs-Ton'),
          ListTile(
            enabled: Platform.isIOS,
            leading: const Icon(Icons.phone_callback_outlined),
            title: const Text('Alarmierungston'),
            subtitle: () {
              if (Platform.isAndroid) return const Text('Auf Android noch nicht verfügbar');
              return Text(Globals.prefs.getString('alarm_sound') ?? 'ABCABCAB');
            }(),
            onTap: () async {
              if (Platform.isAndroid) {
                infoToast('Auf Android noch nicht verfügbar');
                return;
              }
              String selected = Globals.prefs.getString('alarm_sound') ?? 'ABCABCAB';
              String previousPath = Globals.prefs.getString('alarm_soundPath') ?? 'res_alarm_1';

              var player = AssetsAudioPlayer.newPlayer();
              String? playing;

              RealVolume.getCurrentVol(StreamType.MUSIC).then((value) {
                if (value != null && value < 0.05) {
                  infoToast('Musik ist stummgeschaltet');
                }
              });

              dynamic result = await generalDialog(
                color: Colors.blue,
                title: 'Alarmierungston',
                content: StatefulBuilder(builder: (context, sbSetState) {
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Wiedergabe hier leiser als bei Alarmierung'),
                    ...alarmSounds.keys.map((e) {
                      return ListTile(
                        title: Text(e),
                        selected: selected == e,
                        onTap: () {
                          selected = e;
                          if (mounted) sbSetState(() {});
                        },
                        trailing: () {
                          return IconButton(
                            icon: playing == alarmSounds[e] ? const Icon(Icons.stop_outlined) : const Icon(Icons.play_arrow_outlined),
                            onPressed: () async {
                              if (playing == alarmSounds[e]) {
                                await player.stop();
                                playing = null;
                              } else {
                                await player.open(
                                  Audio('android/app/src/main/res/raw/${alarmSounds[e]}.mp3'),
                                  autoStart: true,
                                  volume: 0.5,
                                  loopMode: LoopMode.single,
                                  showNotification: false,
                                );
                                await player.play();
                                playing = alarmSounds[e];
                              }
                              if (mounted) sbSetState(() {});
                            },
                          );
                        }(),
                      );
                    }),
                  ]);
                }),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Abbrechen'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(selected);
                    },
                    child: const Text('OK'),
                  ),
                ],
              );

              player.dispose();

              if (result != null) {
                String selectedPath = alarmSounds[result]!;
                if (selectedPath == previousPath) return;
                Globals.prefs.setString('alarm_sound', result);
                Globals.prefs.setString('alarm_soundPath', selectedPath);
                if (mounted) setState(() {});

                await AwesomeNotifications().removeChannel('alarm');
                await AwesomeNotifications().removeChannel('test');
                if (Platform.isIOS) {
                  initializeAwesomeNotifications();
                } else if (Platform.isAndroid) {
                  // tell the user to restart the app, also reset the DnD prefs setting
                  Globals.prefs.remove('critical_alerts_test');
                  Globals.prefs.remove('critical_alerts');
                  generalDialog(
                    color: Colors.blue,
                    title: 'Neustart erforderlich',
                    content: const Text('Die Änderungen werden erst nach einem Neustart der App übernommen.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ).then((value) {
                    SystemNavigator.pop();
                  });
                }
              }
            },
            trailing: const Icon(Icons.arrow_drop_down_circle_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: const Text('Alarme stummschalten'),
            onTap: () {
              bool muted = Globals.prefs.getBool('alarms_muted') ?? false;
              Globals.prefs.setBool('alarms_muted', !muted);
              if (mounted) setState(() {});
            },
            trailing: Switch(
              value: Globals.prefs.getBool('alarms_muted') ?? false,
              onChanged: (value) {
                Globals.prefs.setBool('alarms_muted', value);
                if (mounted) setState(() {});
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in_outlined),
            title: const Text('Tests stummschalten'),
            onTap: () {
              bool muted = Globals.prefs.getBool('alarms_testsMuted') ?? false;
              Globals.prefs.setBool('alarms_testsMuted', !muted);
              if (mounted) setState(() {});
            },
            trailing: Switch(
              value: Globals.prefs.getBool('alarms_testsMuted') ?? false,
              onChanged: (value) {
                Globals.prefs.setBool('alarms_testsMuted', value);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> alarmSounds = {
    'ABCABCAB': 'res_alarm_1',
    'AAAABBBB': 'res_alarm_2',
    'A-A-BB--': 'res_alarm_3',
    'BABACACA': 'res_alarm_4',
  };

  @override
  void onUpdate(UpdateInfo info) {
    if (info.type == UpdateType.ui) {
      if (!mounted || (!info.ids.contains("1") && !info.ids.contains("3"))) return;
      allNotificationSettings = SettingsNotificationData.getAll();
      checkSettings();
    } else if (info.type == UpdateType.station) {
      if (!mounted) return;
      Station.getAll().then((value) {
        stations = value;
        if (mounted) setState(() {});
      });
    }
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                '  $text  ',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
