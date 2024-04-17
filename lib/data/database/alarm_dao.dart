import 'package:ff_alarm/data/models/alarm.dart';
import 'package:floor/floor.dart';

@dao
abstract class AlarmDao {
  @Query('SELECT * FROM Alarm WHERE id = :id')
  Future<Alarm?> getById(String id);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updates(Alarm alarm);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> inserts(Alarm alarm);

  @delete
  Future<void> deletes(Alarm alarm);

  @Query('DELETE FROM Alarm WHERE id = :id')
  Future<void> deleteById(String id);

  @Query('SELECT * FROM Alarm WHERE id < :id ORDER BY id DESC LIMIT :limit')
  Future<List<Alarm>> getWithLowerIdThan(String id, int limit);

  @Query('DELETE FROM Alarm WHERE id LIKE :id||" %"')
  Future<void> deleteByServer(String id);

  @Query('SELECT COUNT(*) FROM Alarm WHERE id LIKE :server||" %"')
  Future<int?> getAmountWithServer(String server);

  @Query('SELECT * FROM Alarm WHERE id LIKE :server||" %" AND date > :date')
  Future<List<Alarm>> getWithServer(String server, int date);
}
