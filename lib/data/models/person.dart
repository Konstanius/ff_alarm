import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';

@entity
class Person {
  @primaryKey
  final int id;

  String firstName;

  String lastName;

  String get fullName => "$firstName $lastName";

  List<int> allowedUnits;

  /// Qualifications Format:
  /// comma separated, no spaces
  /// Supported:
  /// - tm (Truppmann)
  /// - tf (Truppführer)
  /// - agt (Atemschutzgeräteträger)
  /// - gf (Gruppenführer)
  /// - zf (Zugführer)
  /// - ma (Maschinist)
  /// - b (B-Führerschen)
  /// - c1 (C-Führerschein)
  /// - c (C-Führerschein)
  /// - ce (CE-Führerschein)
  /// - bo (Bootsführerschein)
  String qualifications;

  AlarmResponse response;

  DateTime updated;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.allowedUnits,
    required this.qualifications,
    required this.response,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "firstName": "f",
    "lastName": "l",
    "allowedUnits": "au",
    "qualifications": "q",
    "response": "r",
    "updated": "up",
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json[jsonShorts["id"]],
      firstName: json[jsonShorts["firstName"]],
      lastName: json[jsonShorts["lastName"]],
      allowedUnits: List<int>.from(json[jsonShorts["allowedUnits"]]),
      qualifications: json[jsonShorts["qualifications"]],
      response: AlarmResponse.fromJson(json[jsonShorts["response"]]),
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["firstName"]!: firstName,
      jsonShorts["lastName"]!: lastName,
      jsonShorts["allowedUnits"]!: allowedUnits,
      jsonShorts["qualifications"]!: qualifications,
      jsonShorts["response"]!: response.toJson(),
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  static Future<List<Person>> getBatched({
    bool Function(Person)? filter,
    int? limit,
    int startingId = 2 ^ 31,
  }) async {
    var persons = <Person>[];

    int lowestId = startingId;
    const batchSize = 50;
    while (true) {
      var newPersons = await Globals.db.personDao.getWithLowerIdThan(startingId, batchSize);
      if (newPersons.isEmpty) break;

      var toAdd = <Person>[];
      for (var person in newPersons) {
        if (filter == null || filter(person)) toAdd.add(person);
        if (person.id < lowestId) lowestId = person.id;

        if (limit != null && toAdd.length + persons.length >= limit) break;
      }

      persons.addAll(toAdd);
      if ((limit != null && persons.length >= limit )|| newPersons.length < batchSize) break;
    }

    persons.sort((a, b) => a.fullName.compareTo(b.fullName));

    return persons;
  }

  static Future<List<Person>> getAll({bool Function(Person)? filter}) => getBatched(filter: filter);

  static Future<void> update(Person person, bool bc) async {
    var existing = await Globals.db.personDao.getById(person.id);
    if (existing != null) {
      if (existing.updated.isAfter(person.updated)) return;
      await Globals.db.personDao.updates(person);
    } else {
      await Globals.db.personDao.inserts(person);
    }

    if (!bc) return;
    UpdateInfo(UpdateType.person, {person.id});
  }

  static Future<void> delete(int personId, bool bc) async {
    await Globals.db.personDao.deleteById(personId);

    if (!bc) return;
    UpdateInfo(UpdateType.person, {personId});
  }
}
