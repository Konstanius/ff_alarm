import 'dart:convert';
import 'dart:io';

import 'package:ff_alarm/globals.dart';

class Prefs {
  String identifier;
  late Map<String, dynamic> _prefs;

  void setString(String key, String value) {
    _prefs[key] = value;
    save();
  }

  String getString(String key) {
    dynamic value = _prefs[key];
    if (value is String) return value;
    throw Exception('Value for key $key is not a String');
  }

  void setBool(String key, bool value) {
    _prefs[key] = value;
    save();
  }

  bool getBool(String key) {
    dynamic value = _prefs[key];
    if (value is bool) return value;
    throw Exception('Value for key $key is not a bool');
  }

  void setInt(String key, int value) {
    _prefs[key] = value;
    save();
  }

  int getInt(String key) {
    dynamic value = _prefs[key];
    if (value is int) return value;
    throw Exception('Value for key $key is not an int');
  }

  void setDouble(String key, double value) {
    _prefs[key] = value;
    save();
  }

  double getDouble(String key) {
    dynamic value = _prefs[key];
    if (value is double) return value;
    throw Exception('Value for key $key is not a double');
  }

  void setOther(String key, dynamic value) {
    _prefs[key] = value;
    save();
  }

  dynamic getOther(String key) {
    return _prefs[key];
  }

  void remove(String key) {
    _prefs.remove(key);
  }

  void clear() {
    _prefs.clear();
  }

  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  Prefs({required this.identifier}) {
    File file = File('${Globals.filesPath}/prefs/$identifier.json');
    if (file.existsSync()) {
      try {
        _prefs = json.decode(file.readAsStringSync());
      } catch (e) {
        file.deleteSync();
        _prefs = <String, dynamic>{};
      }
    } else {
      _prefs = <String, dynamic>{};
    }
  }

  void save() {
    File file = File('${Globals.filesPath}/prefs/$identifier.json');
    if (!file.existsSync()) file.createSync(recursive: true);
    file.writeAsStringSync(json.encode(_prefs));
  }
}
