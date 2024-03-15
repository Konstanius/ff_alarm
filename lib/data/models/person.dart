import 'package:isar/isar.dart';

part 'person.g.dart';

@collection
class Person {
  @Name('id')
  final Id id;

  @Name('firstName')
  String firstName;

  @Name('lastName')
  String lastName;

  @Name('allowedUnits')
  List<int> allowedUnits;

  /// Qualifications Format (Index basiert):
  /// 0 : Verfügbar allgemein
  /// 1 : Truppmann
  /// 2 : Funkausbildung
  /// 3 : Atemschutzausbildung
  /// 4 : Truppführerausbildung
  /// 5 : Maschinistenausbildung
  /// 6 : Bootsführerausbildung
  /// 7 : Gruppenführerausbildung
  /// 8 : Zugführerausbildung
  /// 9 : Rettungsassistent
  /// 10: Rettungssanitäter
  /// 11: Notfallsanitäter
  /// 12: Notarzt
  @Name('qualifications')
  String qualifications;

  @Name('updated')
  DateTime updated;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.allowedUnits,
    required this.qualifications,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "firstName": "f",
    "lastName": "l",
    "allowedUnits": "au",
    "qualifications": "q",
    "updated": "up",
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json[jsonShorts["id"]],
      firstName: json[jsonShorts["firstName"]],
      lastName: json[jsonShorts["lastName"]],
      allowedUnits: List<int>.from(json[jsonShorts["allowedUnits"]]),
      qualifications: json[jsonShorts["qualifications"]],
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
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }
}
