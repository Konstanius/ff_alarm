import 'package:ff_alarm/data/models/unit.dart';
import 'package:floor/floor.dart';

@dao
abstract class UnitDao {
  @Query('SELECT * FROM Unit WHERE id = :id')
  Future<Unit?> getById(String id);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updates(Unit unit);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> inserts(Unit unit);

  @delete
  Future<void> deletes(Unit unit);

  @Query('DELETE FROM Unit WHERE id = :id')
  Future<void> deleteById(String id);

  @Query('SELECT * FROM Unit WHERE id < :id ORDER BY id DESC LIMIT :limit')
  Future<List<Unit>> getWithLowerIdThan(String id, int limit);

  @Query('DELETE FROM Unit WHERE id LIKE :id||" %"')
  Future<void> deleteByPrefix(String id);

  @Query('SELECT COUNT(*) FROM Unit WHERE id LIKE :prefix||"%"')
  Future<int?> getAmountWithPrefix(String prefix);

  @Query('SELECT * FROM Unit WHERE stationId = :stationId AND id LIKE :prefix||"%"')
  Future<List<Unit>> getWhereStationIn(int stationId, String prefix);
}
