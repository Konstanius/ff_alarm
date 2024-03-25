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
  /// "quali":"startMillis/null":"endMillis/null",...
  /// Supported:
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
  List<Qualification> qualifications;

  bool hasQualification(String type, DateTime checkDate) {
    for (var qualification in qualifications) {
      if (qualification.type != type) continue;
      if (qualification.start == null && qualification.end == null) return false;
      if (qualification.start == null && qualification.end != null) return qualification.end!.isAfter(checkDate);
      if (qualification.start != null && qualification.end == null) return qualification.start!.isBefore(checkDate);
      return qualification.start!.isBefore(checkDate) && qualification.end!.isAfter(checkDate);
    }

    return false;
  }

  AlarmResponse? response;

  int updated;

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
      qualifications: (json[jsonShorts["qualifications"]] as List).map((e) => Qualification.fromString(e)).toList(),
      response: AlarmResponse.fromJson(json[jsonShorts["response"]]),
      updated: json[jsonShorts["updated"]],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["firstName"]!: firstName,
      jsonShorts["lastName"]!: lastName,
      jsonShorts["allowedUnits"]!: allowedUnits,
      jsonShorts["qualifications"]!: qualifications.map((e) => e.toString()).toList(),
      jsonShorts["response"]!: response?.toJson(),
      jsonShorts["updated"]!: updated,
    };
  }

  static Future<List<Person>> getBatched({
    bool Function(Person)? filter,
    int? limit,
    int? startingId,
  }) async {
    var persons = <Person>[];

    int lowestId = startingId ?? double.maxFinite.toInt();
    const batchSize = 50;
    while (true) {
      var newPersons = await Globals.db.personDao.getWithLowerIdThan(lowestId, batchSize);
      if (newPersons.isEmpty) break;

      var toAdd = <Person>[];
      for (var person in newPersons) {
        if (filter == null || filter(person)) toAdd.add(person);
        if (person.id < lowestId) lowestId = person.id;

        if (limit != null && toAdd.length + persons.length >= limit) break;
      }

      persons.addAll(toAdd);
      if ((limit != null && persons.length >= limit) || newPersons.length < batchSize) break;
    }

    persons.sort((a, b) => a.fullName.compareTo(b.fullName));

    return persons;
  }

  static Future<List<Person>> getAll({bool Function(Person)? filter}) => getBatched(filter: filter);

  static Future<void> update(Person person, bool bc) async {
    var existing = await Globals.db.personDao.getById(person.id);
    if (existing != null) {
      if (existing.updated >= person.updated) return;
      await Globals.db.personDao.updates(person);
    } else {
      await Globals.db.personDao.inserts(person);
    }

    if (person.id == Globals.person?.id) Globals.person = person;

    if (!bc) return;
    UpdateInfo(UpdateType.person, {person.id});
  }

  static Future<void> delete(int personId, bool bc) async {
    await Globals.db.personDao.deleteById(personId);

    if (!bc) return;
    UpdateInfo(UpdateType.person, {personId});
  }
}

class Qualification {
  final String type;
  final DateTime? start;
  final DateTime? end;

  Qualification(this.type, this.start, this.end);

  factory Qualification.fromString(String str) {
    var parts = str.split(':');
    String type = parts[0];
    DateTime? start = parts[1] == "0" ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
    DateTime? end = parts[2] == "0" ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]));
    return Qualification(type, start, end);
  }

  @override
  String toString() {
    return "$type:${start?.millisecondsSinceEpoch ?? 0}:${end?.millisecondsSinceEpoch ?? 0}";
  }
}
