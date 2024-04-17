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
  Future<void> deleteByServer(String id);

  @Query('SELECT COUNT(*) FROM Unit WHERE id LIKE :server||" %"')
  Future<int?> getAmountWithServer(String server);

  @Query('SELECT * FROM Unit WHERE stationId = :stationId AND id LIKE :server||" %"')
  Future<List<Unit>> getWhereStationIn(int stationId, String server);

  @Query('SELECT * FROM Unit WHERE id LIKE :server||" %"')
  Future<List<Unit>> getWithServer(String server);

  @Query('SELECT * FROM Unit WHERE id LIKE :server||" %" AND calLSign LIKE :callSign')
  Future<List<Unit>> getWithServerAndCallSign(String server, String callSign);
}
