import 'dart:convert';

import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:floor/floor.dart';

class ListStringConverter extends TypeConverter<List<String>, String> {
  @override
  List<String> decode(String databaseValue) {
    var decoded = jsonDecode(databaseValue);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return [];
  }

  @override
  String encode(List<String> value) {
    return jsonEncode(value);
  }
}

class ListIntConverter extends TypeConverter<List<int>, String> {
  @override
  List<int> decode(String databaseValue) {
    var decoded = jsonDecode(databaseValue);
    if (decoded is List) {
      return decoded.map((e) => int.parse(e.toString())).toList();
    }
    return [];
  }

  @override
  String encode(List<int> value) {
    return jsonEncode(value);
  }
}

class NullableListIntConverter extends TypeConverter<List<int>?, String?> {
  @override
  List<int>? decode(String? databaseValue) {
    if (databaseValue == null) {
      return null;
    }
    var decoded = jsonDecode(databaseValue);
    if (decoded is List) {
      return decoded.map((e) => int.parse(e.toString())).toList();
    }
    return [];
  }

  @override
  String? encode(List<int>? value) {
    if (value == null) {
      return null;
    }
    return jsonEncode(value);
  }
}

class MapIntAlarmResponseConverter extends TypeConverter<Map<int, AlarmResponse>, String> {
  @override
  Map<int, AlarmResponse> decode(String databaseValue) {
    Map<String, dynamic> decoded = jsonDecode(databaseValue);
    Map<int, AlarmResponse> result = {};
    decoded.forEach((key, value) {
      var response = AlarmResponse.fromJson(value);
      if (response != null) result[int.parse(key)] = response;
    });
    return result;
  }

  @override
  String encode(Map<int, AlarmResponse> value) {
    Map<String, dynamic> result = {};
    value.forEach((key, value) {
      result[key.toString()] = value.toJson();
    });
    return jsonEncode(result);
  }
}

class AlarmResponseConverter extends TypeConverter<AlarmResponse?, String?> {
  @override
  AlarmResponse? decode(String? databaseValue) {
    if (databaseValue == null) return null;
    return AlarmResponse.fromJson(jsonDecode(databaseValue));
  }

  @override
  String? encode(AlarmResponse? value) {
    if (value == null) return null;
    return jsonEncode(value.toJson());
  }
}

class DateTimeConverter extends TypeConverter<DateTime, int> {
  @override
  DateTime decode(int databaseValue) {
    return DateTime.fromMillisecondsSinceEpoch(databaseValue);
  }

  @override
  int encode(DateTime value) {
    return value.millisecondsSinceEpoch;
  }
}

class ListUnitPositionConverter extends TypeConverter<List<UnitPosition>, String> {
  @override
  List<UnitPosition> decode(String databaseValue) {
    var decoded = jsonDecode(databaseValue);
    if (decoded is List) {
      return decoded.map((e) => UnitPosition.values[e]).toList();
    }
    return [];
  }

  @override
  String encode(List<UnitPosition> value) {
    return jsonEncode(value.map((e) => e.index).toList());
  }
}
