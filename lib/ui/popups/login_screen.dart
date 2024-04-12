import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/data/interfaces/guest_interface.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:photo_view/photo_view.dart';

import '../../data/interfaces/alarm_interface.dart';
import '../../data/interfaces/station_interface.dart';
import '../../data/interfaces/unit_interface.dart';
import '../../firebase_options.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// QR code needs to contain:
/// - authKey
/// - domain parts
/// - personId
class _LoginScreenState extends State<LoginScreen> {
  TextEditingController codeController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Globals.localPersons.isNotEmpty,
        title: const Text('Daten-Quelle registrieren'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                  return Scaffold(
                    appBar: AppBar(
                      automaticallyImplyLeading: true,
                      title: const Text('Alarmierungsbereiche'),
                    ),
                    body: Center(
                      child: PhotoView(
                        imageProvider: const AssetImage('assets/alarm_areas_jena.jpg'),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                      ),
                    ),
                  );
                }));
              },
              child: Image.asset(
                'assets/alarm_areas_jena.jpg',
                height: MediaQuery.of(context).size.height / 5,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              aboutDialog();
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.help_outline),
                  SizedBox(width: 5),
                  Text('Wie funktioniert das?'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Die Daten-Quelle enthält Informationen über den Server der Daten-Quelle (Leitstelle), deine Person und einen Sicherheitsschlüssel.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextFormField(
              controller: codeController,
              readOnly: Globals.context!.loaderOverlay.visible,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Code',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  onPressed: () async {
                    try {
                      String? code = await QRScannerPage.scanQR();
                      if (code == null) return;
                      codeController.text = code;
                    } catch (e, s) {
                      Logger.error('LoginScreen: $e, $s');
                      errorToast('QR-Code konnte nicht gescannt werden');
                    }
                  },
                ),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              maxLines: 1,
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                String code = codeController.text;
                var json = jsonDecode(utf8.decode(gzip.decode(base64.decode(code))));

                String? authKey = json['a'];
                String? server = json['d'];
                int? personId = json['p'];

                if (authKey == null || server == null || personId == null) {
                  errorToast('Ungültiger Code');
                  return;
                }

                for (var person in Globals.localPersons.values) {
                  if (person.server == server) {
                    errorToast('Diese Daten-Quelle ist bereits auf deinem Gerät registriert!');
                    return;
                  }
                }

                Uri? uri = Uri.tryParse('http$server');
                if (uri == null) {
                  errorToast('Ungültiger Code');
                  return;
                }

                // show details of data source and ask to confirm
                dynamic confirm = await generalDialog(
                  color: Colors.blue,
                  title: 'Daten-Quelle registrieren',
                  content: Column(
                    children: <Widget>[
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
                        subtitle: Text(server.startsWith('s') ? 'Ja' : 'Nein'),
                      ),
                    ],
                  ),
                  actions: <Widget>[
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
                      child: const Text('Registrieren'),
                    ),
                  ],
                );
                if (confirm != true) return;

                try {
                  Globals.context!.loaderOverlay.show();
                  setState(() {});

                  // delete all data relevant to this server
                  await Globals.db.alarmDao.deleteByPrefix(server);
                  await Globals.db.personDao.deleteByPrefix(server);
                  await Globals.db.stationDao.deleteByPrefix(server);
                  await Globals.db.unitDao.deleteByPrefix(server);

                  var allResponses = SettingsNotificationData.getAll();
                  Set<String> toRemove = {};
                  for (var response in allResponses.entries) {
                    if (response.value.server == server) {
                      toRemove.add(response.key);
                    }
                  }
                  for (var key in toRemove) {
                    allResponses.remove(key);
                  }
                  SettingsNotificationData.delete(toRemove);

                  // regenerate FCM token to prevent old servers from sending notifications to the outdated token
                  // TODO possibly do this in another way
                  try {
                    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
                    await FirebaseMessaging.instance.deleteToken();
                    String? token = await FirebaseMessaging.instance.getToken();
                    if (token != null) {
                      Globals.prefs.setString('fcm_token', token);
                    } else {
                      Globals.prefs.remove('fcm_token');
                    }
                  } catch (e, s) {
                    Logger.error('LoginScreen: $e, $s');
                    errorToast('Google-Server konnten nicht kontaktiert werden');
                    Globals.context!.loaderOverlay.hide();
                    setState(() {});
                    return;
                  }

                  ({String token, int sessionId, Person person}) result;
                  try {
                    result = await GuestInterface.login(personId: personId, key: authKey, server: server);
                  } catch (e, s) {
                    Logger.error('LoginScreen: $e, $s');
                    if (e is AckError) {
                      errorToast(e.errorMessage);
                      Globals.context!.loaderOverlay.hide();
                      setState(() {});
                      return;
                    }
                    errorToast('Server konnte nicht erreicht werden');
                    Globals.context!.loaderOverlay.hide();
                    setState(() {});
                    return;
                  }

                  await Person.update(result.person, false);
                  Globals.localPersons[result.person.id] = result.person;
                  Globals.prefs.setInt('auth_user_$server', result.person.idNumber);
                  Globals.prefs.setInt('auth_session_$server', result.sessionId);
                  Globals.prefs.setString('auth_token_$server', result.token);

                  String registeredUsers = Globals.prefs.getString('registered_users') ?? '[]';
                  List<String> users;
                  try {
                    users = jsonDecode(registeredUsers).cast<String>();
                  } catch (e) {
                    users = [];
                  }
                  if (!users.contains("$server $personId")) {
                    users.add("$server $personId");
                    Globals.prefs.setString('registered_users', jsonEncode(users));
                  }

                  Navigator.pop(Globals.context!);

                  PersonInterface.fetchAll();
                  UnitInterface.fetchAll();
                  StationInterface.fetchAll();
                  AlarmInterface.fetchAll();

                  UpdateInfo(UpdateType.ui, {"3"});
                } catch (e) {
                  Logger.error('LoginScreen: $e');
                  errorToast('Ungültiger Code');
                }
              } catch (e, s) {
                Logger.error('LoginScreen: $e, $s');
                errorToast('Ungültiger Code');
              } finally {
                Globals.context!.loaderOverlay.hide();
                setState(() {});
              }
            },
            child: const Text('Registrieren'),
          ),
        ],
      ),
    );
  }
}
