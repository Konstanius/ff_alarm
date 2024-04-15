import 'package:ff_alarm/data/models/person.dart';
import 'package:floor/floor.dart';

@dao
abstract class PersonDao {
  @Query('SELECT * FROM Person WHERE id = :id')
  Future<Person?> getById(String id);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updates(Person person);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> inserts(Person person);

  @delete
  Future<void> deletes(Person person);

  @Query('DELETE FROM Person WHERE id = :id')
  Future<void> deleteById(String id);

  @Query('SELECT * FROM Person WHERE id < :id ORDER BY id DESC LIMIT :limit')
  Future<List<Person>> getWithLowerIdThan(String id, int limit);

  @Query('DELETE FROM Person WHERE id LIKE :id||" %"')
  Future<void> deleteByPrefix(String id);

  @Query('SELECT COUNT(*) FROM Person WHERE id LIKE :prefix||"%"')
  Future<int?> getAmountWithPrefix(String prefix);

  @Query('SELECT * FROM Person WHERE id IN (:ids)')
  Future<List<Person>> getWhereIn(List<String> ids);
}
