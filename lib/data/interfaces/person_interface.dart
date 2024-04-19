import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '../../globals.dart';
import '../../ui/utils/toasts.dart';

abstract class PersonInterface {
  static Future<void> fetchAll() async {
    List<Person> allPersons = await Person.getAll();

    var servers = Globals.registeredServers;
    var futures = <Future>[];
    for (var server in servers) {
      List<Person> serverPersons = allPersons.where((person) => person.server == server).toList();
      futures.add(fetchAllForServer(server, serverPersons));
    }

    await Future.wait(futures);
  }

  static Future<void> fetchAllForServerSilent(String server) async {
    List<Person> serverPersons = await Globals.db.personDao.getWithServer(server);
    await fetchAllForServer(server, serverPersons);
  }

  static Future<void> fetchAllForServer(String server, List<Person> serverPersons) async {
    StringBuffer sb = StringBuffer();
    for (Person person in serverPersons) {
      sb.write(person.idNumber);
      sb.write(':');
      sb.write(person.updated);
      sb.write(',');
    }

    Map<String, dynamic> persons = {'data': sb.toString()};

    Request response = await Request('personGetAll', persons, server).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<String> updatedIds = {};
    var futures = <Future>[];
    for (Map<String, dynamic> person in response.ackData!['updated']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      Person newPerson = Person.fromJson(person);
      futures.add(Person.update(newPerson, false));
      updatedIds.add(newPerson.id);
    }

    for (int id in response.ackData!['deleted']) {
      if (futures.length > 25) {
        await Future.wait(futures);
        futures.clear();
      }

      String idString = "$server $id";

      futures.add(Person.delete(idString, false));
      updatedIds.add(idString);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.person, updatedIds);
  }

  static Future<({String key, int personId})> create({
    required int stationId,
    required String firstName,
    required String lastName,
    required DateTime birthday,
    required List<int> allowedUnits,
    required List<Qualification> qualifications,
    required String server,
  }) async {
    Map<String, dynamic> data = {
      'stationId': stationId,
      'firstName': firstName,
      'lastName': lastName,
      'birthday': birthday.millisecondsSinceEpoch,
      'allowedUnits': allowedUnits,
      'qualifications': qualifications.map((e) => e.toString()).toList(),
    };

    Request response = await Request('personCreate', data, server).emit(true);

    String key = response.ackData!['key'];
    int id = response.ackData!['id'];

    return (key: key, personId: id);
  }

  static Future<void> testConnection(String server) async {
    Globals.fcmTest = null;

    Globals.context!.loaderOverlay.show();

    try {
      int timeout = 600;
      int startTime = DateTime.now().millisecondsSinceEpoch;
      bool connected = await Request.isConnected(server);
      int endTime = DateTime.now().millisecondsSinceEpoch;
      int duration = endTime - startTime;
      if (connected) {
        int? delay;
        while (timeout > 0) {
          await Future.delayed(const Duration(milliseconds: 10));
          timeout -= 1;

          if (Globals.fcmTest != null && Globals.fcmTest!.server == server) {
            delay = Globals.fcmTest!.receivedTime - startTime;
            break;
          }
        }
        Globals.fcmTest = null;

        generalDialog(
          color: delay != null ? Colors.blue : Colors.amber,
          title: 'Testergebnis',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Verbindung', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Erfolgreich', style: TextStyle(color: Colors.green)),
              ),
              ListTile(
                title: const Text('Ping-Zeit', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${duration}ms',
                  style: TextStyle(color: duration > 300 ? Colors.amber : Colors.green),
                ),
              ),
              ListTile(
                title: const Text('Alarmierungs-Zustellung', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: delay != null
                    ? Text(
                        '${delay}ms',
                        style: TextStyle(color: delay > 3000 ? Colors.amber : Colors.green),
                      )
                    : const Text('Fehlgeschlagen!', style: TextStyle(color: Colors.red)),
              ),
              // TODO help button
            ],
          ),
          actions: [
            DialogActionButton(
              onPressed: () {
                Navigator.of(Globals.context!).pop();
              },
              text: 'OK',
            ),
          ],
        );
      } else {
        generalDialog(
          color: Colors.red,
          title: 'Testergebnis',
          content: const Text('Verbindung fehlgeschlagen!'),
          // TODO help button
          actions: [
            DialogActionButton(
              onPressed: () {
                Navigator.of(Globals.context!).pop();
              },
              text: 'OK',
            ),
          ],
        );
      }
      Globals.context!.loaderOverlay.hide();
    } catch (e, s) {
      exceptionToast(e, s);

      Globals.context!.loaderOverlay.hide();
    }
  }
}
