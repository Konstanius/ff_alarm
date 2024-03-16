import 'package:ff_alarm/data/models/unit.dart';
import 'package:floor/floor.dart';

@dao
abstract class UnitDao {
  @Query('SELECT * FROM Unit WHERE id = :id')
  Future<Unit?> getById(int id);

  @Query('SELECT * FROM Unit')
  Future<List<Unit>> getAll();

  @update
  Future<void> updates(Unit unit);

  @insert
  Future<void> inserts(Unit unit);

  @delete
  Future<void> deletes(Unit unit);

  @Query('DELETE FROM Unit WHERE id = :id')
  Future<void> deleteById(int id);
}