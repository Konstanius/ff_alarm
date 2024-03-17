import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:real_volume/real_volume.dart';

import '../../log/logger.dart';

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

  Future<void> checkSettings() async {
    notificationsBad = 0;
    lifeCycleBad = 0;

    var notifications = await Permission.notification.isGranted;
    if (!notifications) notificationsBad++;

    if (Platform.isAndroid) {
      var ignoreBatteryOptimizations = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!ignoreBatteryOptimizations) lifeCycleBad++;

      var scheduleExactAlarm = await Permission.scheduleExactAlarm.isGranted;
      if (!scheduleExactAlarm) lifeCycleBad++;

      var accessNotificationPolicy = await Permission.accessNotificationPolicy.isGranted;
      if (!accessNotificationPolicy) notificationsBad++;

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
    }

    widget.badge.value = notificationsBad + lifeCycleBad;

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    checkSettings();
    setupListener({UpdateType.ui});
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
              Globals.router.go('/lifecycle');
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
              Globals.router.go('/notifications');
            },
          ),
          const SettingsDivider(text: 'Personalisierung'),
          ListTile(
            leading: const Icon(Icons.phone_callback_outlined),
            title: const Text('Alarmierungston'),
            subtitle: Text(Globals.prefs.getString('alarm_sound') ?? 'Quattro 98 2'),
            onTap: () async {
              String selected = Globals.prefs.getString('alarm_sound') ?? 'Quattro 98 2';

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
                Globals.prefs.setString('alarm_sound', result);
                Globals.prefs.setString('alarm_soundPath', selectedPath);
                if (mounted) setState(() {});
                
                initializeAwesomeNotifications();
              }
            },
            trailing: const Icon(Icons.arrow_drop_down_circle_outlined),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> alarmSounds = {
    'Quattro 98 2': 'res_alarm_1',
    'Quattro Q96': 'res_alarm_2',
    'Einsatzton': 'res_alarm_3',
    'Quattro XLSi': 'res_alarm_4',
  };

  @override
  void onUpdate(UpdateInfo info) {
    if (!mounted || !info.ids.contains(1)) return;
    checkSettings();
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
