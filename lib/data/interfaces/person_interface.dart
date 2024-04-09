import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

import '../../globals.dart';

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
}
