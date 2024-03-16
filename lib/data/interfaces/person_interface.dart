import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';

abstract class PersonInterface {
  static Future<void> fetchAll() async {
    Request response = await Request('alarmGetAll', {}).emit(true);

    var futures = <Future>[];
    for (Map<String, dynamic> person in response.data['persons']) {
      Person newPerson = Person.fromJson(person);
      futures.add(Globals.db.personDao.inserts(newPerson));

      if (futures.length > 25) {
        await Future.wait(futures);
        futures = <Future>[];
      }
    }

    await Future.wait(futures);
  }
}
