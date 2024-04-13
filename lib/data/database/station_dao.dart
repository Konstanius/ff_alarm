import 'package:ff_alarm/data/models/station.dart';
import 'package:floor/floor.dart';

@dao
abstract class StationDao {
  @Query('SELECT * FROM Station WHERE id = :id')
  Future<Station?> getById(String id);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updates(Station station);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> inserts(Station station);

  @delete
  Future<void> deletes(Station station);

  @Query('DELETE FROM Station WHERE id = :id')
  Future<void> deleteById(String id);

  @Query('SELECT * FROM Station WHERE id < :id ORDER BY id DESC LIMIT :limit')
  Future<List<Station>> getWithLowerIdThan(String id, int limit);

  @Query('DELETE FROM Station WHERE id LIKE :id||" %"')
  Future<void> deleteByPrefix(String id);

  @Query('SELECT COUNT(*) FROM Station WHERE id LIKE :prefix||"%"')
  Future<int?> getAmountWithPrefix(String prefix);
}
