import 'dart:io';

import 'package:ff_alarm/data/interfaces/alarm_interface.dart';
import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:floor/floor.dart';

@entity
class Person {
  @primaryKey
  final String id;
  String get server => id.split(' ')[0];
  int get idNumber => int.parse(id.split(' ')[1]);

  String firstName;

  String lastName;

  String get fullName => "$firstName $lastName";

  DateTime birthday;
  int get age => DateTime.now().difference(birthday).inDays ~/ 365;

  /// The ids of the units that this user is allowed to operate
  /// If an integer is negative, that means the user has been removed from the unit, and the id shall not be added to the list, when the unit is changed to or from the station
  /// If the integer is positive, that means the user should be alarmed for the unit
  /// If the integer is not present, the unit is not associated with the user in any way, and therefore the user should not be alarmed for it
  List<int> allowedUnits;
  List<String> get allowedUnitProperIds => allowedUnits.where((element) => element > 0).map((e) => "$server $e").toList();

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
  ///
  /// hardcoded: zf,gf,agt,ma
  List<Qualification> qualifications;

  List<Qualification> visibleQualificationsAt(DateTime date) {
    List<Qualification> active = [];

    for (var qualification in qualifications) {
      if (qualification.type.startsWith("_")) continue;
      if (qualification.start == null && qualification.end == null) continue;
      if (qualification.start == null && qualification.end != null && qualification.end!.isAfter(date)) active.add(qualification);
      if (qualification.start != null && qualification.end == null && qualification.start!.isBefore(date)) active.add(qualification);
      if (qualification.start != null && qualification.end != null && qualification.start!.isBefore(date) && qualification.end!.isAfter(date)) active.add(qualification);
    }

    return active;
  }

  bool hasQualification(String type, DateTime checkDate) {
    type = type.toLowerCase();
    for (var qualification in qualifications) {
      String thisType = qualification.type.toLowerCase();
      if (thisType != type) continue;
      if (qualification.start == null && qualification.end == null) return false;
      if (qualification.start == null && qualification.end != null) return qualification.end!.isAfter(checkDate);
      if (qualification.start != null && qualification.end == null) return qualification.start!.isBefore(checkDate);
      return qualification.start!.isBefore(checkDate) && qualification.end!.isAfter(checkDate);
    }

    return false;
  }

  int updated;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.birthday,
    required this.allowedUnits,
    required this.qualifications,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "server": "s",
    "id": "i",
    "firstName": "f",
    "lastName": "l",
    "birthday": "b",
    "allowedUnits": "au",
    "qualifications": "q",
    "updated": "up",
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: "${json[jsonShorts["server"]]} ${json[jsonShorts["id"]]}",
      firstName: json[jsonShorts["firstName"]],
      lastName: json[jsonShorts["lastName"]],
      birthday: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["birthday"]]),
      allowedUnits: List<int>.from(json[jsonShorts["allowedUnits"]]),
      qualifications: (json[jsonShorts["qualifications"]] as List).map((e) => Qualification.fromString(e)).toList(),
      updated: json[jsonShorts["updated"]],
    );
  }

  static Future<List<Person>> getBatched({
    bool Function(Person)? filter,
    int? limit,
    String? startingId,
  }) async {
    var persons = <Person>[];

    String lowestId = startingId ?? "\u{10FFFF}";
    const batchSize = 50;
    while (true) {
      var newPersons = await Globals.db.personDao.getWithLowerIdThan(lowestId, batchSize);
      if (newPersons.isEmpty) break;

      var toAdd = <Person>[];
      for (var person in newPersons) {
        if (filter == null || filter(person)) toAdd.add(person);
        if (person.id.compareTo(lowestId) < 0) lowestId = person.id;

        if (limit != null && toAdd.length + persons.length >= limit) break;
      }

      persons.addAll(toAdd);
      if ((limit != null && persons.length >= limit) || newPersons.length < batchSize) break;
    }

    persons.sort((a, b) => a.fullName.compareTo(b.fullName));

    return persons;
  }

  static Future<List<Person>> getAll({bool Function(Person)? filter}) => getBatched(filter: filter);

  static Future<List<Person>> getByIds(Iterable<String> ids) async {
    var futures = ids.map((e) => Globals.db.personDao.getById(e));
    var persons = await Future.wait(futures);
    persons.removeWhere((element) => element == null);
    return persons.cast<Person>();
  }

  static Future<void> update(Person person, bool bc) async {
    // guarantee, that:
    // id contains a space
    // id split 0 != null
    // id split 1 != 0
    var splits = person.id.split(' ');
    if (splits.length != 2 || splits[0].isEmpty || splits[1].isEmpty) return;
    if (splits[0] == 'null' || splits[1] == '0') return;
    if (int.tryParse(splits[1]) == null) return;

    var existing = await Globals.db.personDao.getById(person.id);
    if (existing != null) {
      if (existing.updated >= person.updated) return;
      await Globals.db.personDao.updates(person);
    } else {
      await Globals.db.personDao.inserts(person);
    }

    if (Globals.localPersons.containsKey(person.id)) {
      Person old = Globals.localPersons[person.id]!;
      Globals.localPersons[person.id] = person;

      if (old.allowedUnits.length != person.allowedUnits.length) {
        UnitInterface.fetchAllForServerSilent(person.server);
        AlarmInterface.fetchAllForServerSilent(person.server);
      }
    }

    if (!bc) return;
    UpdateInfo(UpdateType.person, {person.id});
  }

  static Future<void> delete(String personId, bool bc) async {
    await Globals.db.personDao.deleteById(personId);

    if (!bc) return;
    UpdateInfo(UpdateType.person, {personId});
  }

  static Future<int?> getAmount(String server) => Globals.db.personDao.getAmountWithServer(server);
}

class Qualification {
  String type;
  DateTime? start;
  DateTime? end;

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
    if (type.contains(':')) throw AckError(HttpStatus.badRequest, "Qualifikationen können nicht ':' enthalten.");
    return "$type:${start?.millisecondsSinceEpoch ?? 0}:${end?.millisecondsSinceEpoch ?? 0}";
  }

  String get displayString {
    if (type.startsWith("_")) return type.substring(1);
    return type;
  }

  bool get hidden => type.startsWith("_");

  bool isActive(DateTime date) {
    if (start == null && end == null) return false;
    if (start == null && end != null) return end!.isAfter(date);
    if (start != null && end == null) return start!.isBefore(date);
    return start!.isBefore(date) && end!.isAfter(date);
  }
}
