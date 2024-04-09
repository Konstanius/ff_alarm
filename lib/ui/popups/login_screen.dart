import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/data/interfaces/guest_interface.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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
///
/// On successful auth, compare new domain with last domain - if different, completely reset database
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
        automaticallyImplyLeading: false,
        title: const Text('Login'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Bitte Registrierungscode eingeben:',
              style: TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: codeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Code',
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              try {
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
                  return;
                }

                String code = codeController.text;
                var json = jsonDecode(utf8.decode(gzip.decode(base64.decode(code))));

                String? authKey = json['a'];
                String? server = json['d'];
                int? personId = json['p'];

                if (authKey == null || server == null || personId == null) {
                  errorToast('Ungültiger Code');
                  return;
                }

                ({String token, int sessionId, Person person}) result;
                try {
                  result = await GuestInterface.login(personId: personId, key: authKey, server: server);
                } catch (e, s) {
                  Logger.error('LoginScreen: $e, $s');
                  if (e is AckError) {
                    errorToast(e.errorMessage);
                    return;
                  }
                  errorToast('Server konnte nicht erreicht werden');
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
            },
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );
  }
}
