import 'package:ff_alarm/data/models/alarm.dart';
import 'package:floor/floor.dart';

@dao
abstract class AlarmDao {
  @Query('SELECT * FROM Alarm WHERE id = :id')
  Future<Alarm?> getById(int id);

  @update
  Future<void> updates(Alarm alarm);

  @insert
  Future<void> inserts(Alarm alarm);

  @delete
  Future<void> deletes(Alarm alarm);

  @Query('DELETE FROM Alarm WHERE id = :id')
  Future<void> deleteById(int id);
}