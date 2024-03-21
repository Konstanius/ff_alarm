import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';

abstract class PersonInterface {
  static Future<void> fetchAll() async {
    var allPersons = await Person.getAll();

    StringBuffer sb = StringBuffer();
    for (Person person in allPersons) {
      sb.write(person.id);
      sb.write(':');
      sb.write(person.updated);
      sb.write(',');
    }

    Map<String, dynamic> persons = {'data': sb.toString()};

    Request response = await Request('personGetAll', persons).emit(true);
    if (response.ackData!.isEmpty) return;

    Set<int> updatedIds = {};
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

      futures.add(Person.delete(id, false));
      updatedIds.remove(id);
    }

    await Future.wait(futures);

    UpdateInfo(UpdateType.person, updatedIds);
  }

  static Future<Person> checkAuthentication({required int personId, required String authKey}) async {
    Request response = await Request('personCheckAuth', {'id': personId, 'authKey': authKey}).emit(true, guest: true);
    Person person = Person.fromJson(response.ackData!);
    return person;
  }
}
