// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$AppDatabaseBuilder databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$AppDatabaseBuilder inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  /// Adds migrations to the builder.
  _$AppDatabaseBuilder addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  /// Adds a database [Callback] to the builder.
  _$AppDatabaseBuilder addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  /// Creates the database and initializes it.
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  AlarmDao? _alarmDaoInstance;

  StationDao? _stationDaoInstance;

  UnitDao? _unitDaoInstance;

  PersonDao? _personDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Alarm` (`id` TEXT NOT NULL, `type` TEXT NOT NULL, `word` TEXT NOT NULL, `date` INTEGER NOT NULL, `number` INTEGER NOT NULL, `address` TEXT NOT NULL, `notes` TEXT NOT NULL, `units` TEXT NOT NULL, `responses` TEXT NOT NULL, `updated` INTEGER NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Station` (`id` TEXT NOT NULL, `name` TEXT NOT NULL, `area` TEXT NOT NULL, `prefix` TEXT NOT NULL, `stationNumber` INTEGER NOT NULL, `address` TEXT NOT NULL, `coordinates` TEXT NOT NULL, `persons` TEXT NOT NULL, `adminPersons` TEXT NOT NULL, `updated` INTEGER NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Unit` (`id` TEXT NOT NULL, `stationId` INTEGER NOT NULL, `callSign` TEXT NOT NULL, `unitDescription` TEXT NOT NULL, `status` INTEGER NOT NULL, `positions` TEXT NOT NULL, `capacity` INTEGER NOT NULL, `updated` INTEGER NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Person` (`id` TEXT NOT NULL, `firstName` TEXT NOT NULL, `lastName` TEXT NOT NULL, `birthday` INTEGER NOT NULL, `allowedUnits` TEXT NOT NULL, `qualifications` TEXT NOT NULL, `updated` INTEGER NOT NULL, PRIMARY KEY (`id`))');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  AlarmDao get alarmDao {
    return _alarmDaoInstance ??= _$AlarmDao(database, changeListener);
  }

  @override
  StationDao get stationDao {
    return _stationDaoInstance ??= _$StationDao(database, changeListener);
  }

  @override
  UnitDao get unitDao {
    return _unitDaoInstance ??= _$UnitDao(database, changeListener);
  }

  @override
  PersonDao get personDao {
    return _personDaoInstance ??= _$PersonDao(database, changeListener);
  }
}

class _$AlarmDao extends AlarmDao {
  _$AlarmDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _alarmInsertionAdapter = InsertionAdapter(
            database,
            'Alarm',
            (Alarm item) => <String, Object?>{
                  'id': item.id,
                  'type': item.type,
                  'word': item.word,
                  'date': _dateTimeConverter.encode(item.date),
                  'number': item.number,
                  'address': item.address,
                  'notes': _listStringConverter.encode(item.notes),
                  'units': _listIntConverter.encode(item.units),
                  'responses':
                      _mapIntAlarmResponseConverter.encode(item.responses),
                  'updated': item.updated
                }),
        _alarmUpdateAdapter = UpdateAdapter(
            database,
            'Alarm',
            ['id'],
            (Alarm item) => <String, Object?>{
                  'id': item.id,
                  'type': item.type,
                  'word': item.word,
                  'date': _dateTimeConverter.encode(item.date),
                  'number': item.number,
                  'address': item.address,
                  'notes': _listStringConverter.encode(item.notes),
                  'units': _listIntConverter.encode(item.units),
                  'responses':
                      _mapIntAlarmResponseConverter.encode(item.responses),
                  'updated': item.updated
                }),
        _alarmDeletionAdapter = DeletionAdapter(
            database,
            'Alarm',
            ['id'],
            (Alarm item) => <String, Object?>{
                  'id': item.id,
                  'type': item.type,
                  'word': item.word,
                  'date': _dateTimeConverter.encode(item.date),
                  'number': item.number,
                  'address': item.address,
                  'notes': _listStringConverter.encode(item.notes),
                  'units': _listIntConverter.encode(item.units),
                  'responses':
                      _mapIntAlarmResponseConverter.encode(item.responses),
                  'updated': item.updated
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Alarm> _alarmInsertionAdapter;

  final UpdateAdapter<Alarm> _alarmUpdateAdapter;

  final DeletionAdapter<Alarm> _alarmDeletionAdapter;

  @override
  Future<Alarm?> getById(String id) async {
    return _queryAdapter.query('SELECT * FROM Alarm WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Alarm(
            id: row['id'] as String,
            type: row['type'] as String,
            word: row['word'] as String,
            date: _dateTimeConverter.decode(row['date'] as int),
            number: row['number'] as int,
            address: row['address'] as String,
            notes: _listStringConverter.decode(row['notes'] as String),
            units: _listIntConverter.decode(row['units'] as String),
            responses: _mapIntAlarmResponseConverter
                .decode(row['responses'] as String),
            updated: row['updated'] as int),
        arguments: [id]);
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM Alarm WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<List<Alarm>> getWithLowerIdThan(
    String id,
    int limit,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Alarm WHERE id < ?1 ORDER BY id DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Alarm(
            id: row['id'] as String,
            type: row['type'] as String,
            word: row['word'] as String,
            date: _dateTimeConverter.decode(row['date'] as int),
            number: row['number'] as int,
            address: row['address'] as String,
            notes: _listStringConverter.decode(row['notes'] as String),
            units: _listIntConverter.decode(row['units'] as String),
            responses: _mapIntAlarmResponseConverter
                .decode(row['responses'] as String),
            updated: row['updated'] as int),
        arguments: [id, limit]);
  }

  @override
  Future<void> deleteByServer(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Alarm WHERE id LIKE ?1||\" %\"',
        arguments: [id]);
  }

  @override
  Future<int?> getAmountWithServer(String server) async {
    return _queryAdapter.query(
        'SELECT COUNT(*) FROM Alarm WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        arguments: [server]);
  }

  @override
  Future<List<Alarm>> getWithServer(
    String server,
    int date,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Alarm WHERE id LIKE ?1||\" %\" AND date > ?2',
        mapper: (Map<String, Object?> row) => Alarm(
            id: row['id'] as String,
            type: row['type'] as String,
            word: row['word'] as String,
            date: _dateTimeConverter.decode(row['date'] as int),
            number: row['number'] as int,
            address: row['address'] as String,
            notes: _listStringConverter.decode(row['notes'] as String),
            units: _listIntConverter.decode(row['units'] as String),
            responses: _mapIntAlarmResponseConverter
                .decode(row['responses'] as String),
            updated: row['updated'] as int),
        arguments: [server, date]);
  }

  @override
  Future<void> inserts(Alarm alarm) async {
    await _alarmInsertionAdapter.insert(alarm, OnConflictStrategy.replace);
  }

  @override
  Future<void> updates(Alarm alarm) async {
    await _alarmUpdateAdapter.update(alarm, OnConflictStrategy.replace);
  }

  @override
  Future<void> deletes(Alarm alarm) async {
    await _alarmDeletionAdapter.delete(alarm);
  }
}

class _$StationDao extends StationDao {
  _$StationDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _stationInsertionAdapter = InsertionAdapter(
            database,
            'Station',
            (Station item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'area': item.area,
                  'prefix': item.prefix,
                  'stationNumber': item.stationNumber,
                  'address': item.address,
                  'coordinates': item.coordinates,
                  'persons': _listIntConverter.encode(item.persons),
                  'adminPersons': _listIntConverter.encode(item.adminPersons),
                  'updated': item.updated
                }),
        _stationUpdateAdapter = UpdateAdapter(
            database,
            'Station',
            ['id'],
            (Station item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'area': item.area,
                  'prefix': item.prefix,
                  'stationNumber': item.stationNumber,
                  'address': item.address,
                  'coordinates': item.coordinates,
                  'persons': _listIntConverter.encode(item.persons),
                  'adminPersons': _listIntConverter.encode(item.adminPersons),
                  'updated': item.updated
                }),
        _stationDeletionAdapter = DeletionAdapter(
            database,
            'Station',
            ['id'],
            (Station item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'area': item.area,
                  'prefix': item.prefix,
                  'stationNumber': item.stationNumber,
                  'address': item.address,
                  'coordinates': item.coordinates,
                  'persons': _listIntConverter.encode(item.persons),
                  'adminPersons': _listIntConverter.encode(item.adminPersons),
                  'updated': item.updated
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Station> _stationInsertionAdapter;

  final UpdateAdapter<Station> _stationUpdateAdapter;

  final DeletionAdapter<Station> _stationDeletionAdapter;

  @override
  Future<Station?> getById(String id) async {
    return _queryAdapter.query('SELECT * FROM Station WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Station(
            id: row['id'] as String,
            name: row['name'] as String,
            area: row['area'] as String,
            prefix: row['prefix'] as String,
            stationNumber: row['stationNumber'] as int,
            address: row['address'] as String,
            coordinates: row['coordinates'] as String,
            updated: row['updated'] as int,
            persons: _listIntConverter.decode(row['persons'] as String),
            adminPersons:
                _listIntConverter.decode(row['adminPersons'] as String)),
        arguments: [id]);
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM Station WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<List<Station>> getWithLowerIdThan(
    String id,
    int limit,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Station WHERE id < ?1 ORDER BY id DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Station(
            id: row['id'] as String,
            name: row['name'] as String,
            area: row['area'] as String,
            prefix: row['prefix'] as String,
            stationNumber: row['stationNumber'] as int,
            address: row['address'] as String,
            coordinates: row['coordinates'] as String,
            updated: row['updated'] as int,
            persons: _listIntConverter.decode(row['persons'] as String),
            adminPersons:
                _listIntConverter.decode(row['adminPersons'] as String)),
        arguments: [id, limit]);
  }

  @override
  Future<void> deleteByServer(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Station WHERE id LIKE ?1||\" %\"',
        arguments: [id]);
  }

  @override
  Future<int?> getAmountWithServer(String server) async {
    return _queryAdapter.query(
        'SELECT COUNT(*) FROM Station WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        arguments: [server]);
  }

  @override
  Future<List<Station>> getWithServer(String server) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Station WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => Station(
            id: row['id'] as String,
            name: row['name'] as String,
            area: row['area'] as String,
            prefix: row['prefix'] as String,
            stationNumber: row['stationNumber'] as int,
            address: row['address'] as String,
            coordinates: row['coordinates'] as String,
            updated: row['updated'] as int,
            persons: _listIntConverter.decode(row['persons'] as String),
            adminPersons:
                _listIntConverter.decode(row['adminPersons'] as String)),
        arguments: [server]);
  }

  @override
  Future<void> inserts(Station station) async {
    await _stationInsertionAdapter.insert(station, OnConflictStrategy.replace);
  }

  @override
  Future<void> updates(Station station) async {
    await _stationUpdateAdapter.update(station, OnConflictStrategy.replace);
  }

  @override
  Future<void> deletes(Station station) async {
    await _stationDeletionAdapter.delete(station);
  }
}

class _$UnitDao extends UnitDao {
  _$UnitDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _unitInsertionAdapter = InsertionAdapter(
            database,
            'Unit',
            (Unit item) => <String, Object?>{
                  'id': item.id,
                  'stationId': item.stationId,
                  'callSign': item.callSign,
                  'unitDescription': item.unitDescription,
                  'status': item.status,
                  'positions':
                      _listUnitPositionConverter.encode(item.positions),
                  'capacity': item.capacity,
                  'updated': item.updated
                }),
        _unitUpdateAdapter = UpdateAdapter(
            database,
            'Unit',
            ['id'],
            (Unit item) => <String, Object?>{
                  'id': item.id,
                  'stationId': item.stationId,
                  'callSign': item.callSign,
                  'unitDescription': item.unitDescription,
                  'status': item.status,
                  'positions':
                      _listUnitPositionConverter.encode(item.positions),
                  'capacity': item.capacity,
                  'updated': item.updated
                }),
        _unitDeletionAdapter = DeletionAdapter(
            database,
            'Unit',
            ['id'],
            (Unit item) => <String, Object?>{
                  'id': item.id,
                  'stationId': item.stationId,
                  'callSign': item.callSign,
                  'unitDescription': item.unitDescription,
                  'status': item.status,
                  'positions':
                      _listUnitPositionConverter.encode(item.positions),
                  'capacity': item.capacity,
                  'updated': item.updated
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Unit> _unitInsertionAdapter;

  final UpdateAdapter<Unit> _unitUpdateAdapter;

  final DeletionAdapter<Unit> _unitDeletionAdapter;

  @override
  Future<Unit?> getById(String id) async {
    return _queryAdapter.query('SELECT * FROM Unit WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Unit(
            id: row['id'] as String,
            stationId: row['stationId'] as int,
            callSign: row['callSign'] as String,
            unitDescription: row['unitDescription'] as String,
            status: row['status'] as int,
            positions:
                _listUnitPositionConverter.decode(row['positions'] as String),
            capacity: row['capacity'] as int,
            updated: row['updated'] as int),
        arguments: [id]);
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM Unit WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<List<Unit>> getWithLowerIdThan(
    String id,
    int limit,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Unit WHERE id < ?1 ORDER BY id DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Unit(
            id: row['id'] as String,
            stationId: row['stationId'] as int,
            callSign: row['callSign'] as String,
            unitDescription: row['unitDescription'] as String,
            status: row['status'] as int,
            positions:
                _listUnitPositionConverter.decode(row['positions'] as String),
            capacity: row['capacity'] as int,
            updated: row['updated'] as int),
        arguments: [id, limit]);
  }

  @override
  Future<void> deleteByServer(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Unit WHERE id LIKE ?1||\" %\"',
        arguments: [id]);
  }

  @override
  Future<int?> getAmountWithServer(String server) async {
    return _queryAdapter.query(
        'SELECT COUNT(*) FROM Unit WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        arguments: [server]);
  }

  @override
  Future<List<Unit>> getWhereStationIn(
    int stationId,
    String server,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Unit WHERE stationId = ?1 AND id LIKE ?2||\" %\"',
        mapper: (Map<String, Object?> row) => Unit(
            id: row['id'] as String,
            stationId: row['stationId'] as int,
            callSign: row['callSign'] as String,
            unitDescription: row['unitDescription'] as String,
            status: row['status'] as int,
            positions:
                _listUnitPositionConverter.decode(row['positions'] as String),
            capacity: row['capacity'] as int,
            updated: row['updated'] as int),
        arguments: [stationId, server]);
  }

  @override
  Future<List<Unit>> getWithServer(String server) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Unit WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => Unit(
            id: row['id'] as String,
            stationId: row['stationId'] as int,
            callSign: row['callSign'] as String,
            unitDescription: row['unitDescription'] as String,
            status: row['status'] as int,
            positions:
                _listUnitPositionConverter.decode(row['positions'] as String),
            capacity: row['capacity'] as int,
            updated: row['updated'] as int),
        arguments: [server]);
  }

  @override
  Future<List<Unit>> getWithServerAndCallSign(
    String server,
    String callSign,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Unit WHERE id LIKE ?1||\" %\" AND calLSign LIKE ?2',
        mapper: (Map<String, Object?> row) => Unit(
            id: row['id'] as String,
            stationId: row['stationId'] as int,
            callSign: row['callSign'] as String,
            unitDescription: row['unitDescription'] as String,
            status: row['status'] as int,
            positions:
                _listUnitPositionConverter.decode(row['positions'] as String),
            capacity: row['capacity'] as int,
            updated: row['updated'] as int),
        arguments: [server, callSign]);
  }

  @override
  Future<void> inserts(Unit unit) async {
    await _unitInsertionAdapter.insert(unit, OnConflictStrategy.replace);
  }

  @override
  Future<void> updates(Unit unit) async {
    await _unitUpdateAdapter.update(unit, OnConflictStrategy.replace);
  }

  @override
  Future<void> deletes(Unit unit) async {
    await _unitDeletionAdapter.delete(unit);
  }
}

class _$PersonDao extends PersonDao {
  _$PersonDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _personInsertionAdapter = InsertionAdapter(
            database,
            'Person',
            (Person item) => <String, Object?>{
                  'id': item.id,
                  'firstName': item.firstName,
                  'lastName': item.lastName,
                  'birthday': _dateTimeConverter.encode(item.birthday),
                  'allowedUnits': _listIntConverter.encode(item.allowedUnits),
                  'qualifications':
                      _listQualificationConverter.encode(item.qualifications),
                  'updated': item.updated
                }),
        _personUpdateAdapter = UpdateAdapter(
            database,
            'Person',
            ['id'],
            (Person item) => <String, Object?>{
                  'id': item.id,
                  'firstName': item.firstName,
                  'lastName': item.lastName,
                  'birthday': _dateTimeConverter.encode(item.birthday),
                  'allowedUnits': _listIntConverter.encode(item.allowedUnits),
                  'qualifications':
                      _listQualificationConverter.encode(item.qualifications),
                  'updated': item.updated
                }),
        _personDeletionAdapter = DeletionAdapter(
            database,
            'Person',
            ['id'],
            (Person item) => <String, Object?>{
                  'id': item.id,
                  'firstName': item.firstName,
                  'lastName': item.lastName,
                  'birthday': _dateTimeConverter.encode(item.birthday),
                  'allowedUnits': _listIntConverter.encode(item.allowedUnits),
                  'qualifications':
                      _listQualificationConverter.encode(item.qualifications),
                  'updated': item.updated
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Person> _personInsertionAdapter;

  final UpdateAdapter<Person> _personUpdateAdapter;

  final DeletionAdapter<Person> _personDeletionAdapter;

  @override
  Future<Person?> getById(String id) async {
    return _queryAdapter.query('SELECT * FROM Person WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Person(
            id: row['id'] as String,
            firstName: row['firstName'] as String,
            lastName: row['lastName'] as String,
            birthday: _dateTimeConverter.decode(row['birthday'] as int),
            allowedUnits:
                _listIntConverter.decode(row['allowedUnits'] as String),
            qualifications: _listQualificationConverter
                .decode(row['qualifications'] as String),
            updated: row['updated'] as int),
        arguments: [id]);
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM Person WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<List<Person>> getWithLowerIdThan(
    String id,
    int limit,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Person WHERE id < ?1 ORDER BY id DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Person(
            id: row['id'] as String,
            firstName: row['firstName'] as String,
            lastName: row['lastName'] as String,
            birthday: _dateTimeConverter.decode(row['birthday'] as int),
            allowedUnits:
                _listIntConverter.decode(row['allowedUnits'] as String),
            qualifications: _listQualificationConverter
                .decode(row['qualifications'] as String),
            updated: row['updated'] as int),
        arguments: [id, limit]);
  }

  @override
  Future<void> deleteByServer(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Person WHERE id LIKE ?1||\" %\"',
        arguments: [id]);
  }

  @override
  Future<int?> getAmountWithServer(String server) async {
    return _queryAdapter.query(
        'SELECT COUNT(*) FROM Person WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        arguments: [server]);
  }

  @override
  Future<List<Person>> getWithServer(String server) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Person WHERE id LIKE ?1||\" %\"',
        mapper: (Map<String, Object?> row) => Person(
            id: row['id'] as String,
            firstName: row['firstName'] as String,
            lastName: row['lastName'] as String,
            birthday: _dateTimeConverter.decode(row['birthday'] as int),
            allowedUnits:
                _listIntConverter.decode(row['allowedUnits'] as String),
            qualifications: _listQualificationConverter
                .decode(row['qualifications'] as String),
            updated: row['updated'] as int),
        arguments: [server]);
  }

  @override
  Future<List<Person>> getWhereIn(List<String> ids) async {
    const offset = 1;
    final _sqliteVariablesForIds =
        Iterable<String>.generate(ids.length, (i) => '?${i + offset}')
            .join(',');
    return _queryAdapter.queryList(
        'SELECT * FROM Person WHERE id IN (' + _sqliteVariablesForIds + ')',
        mapper: (Map<String, Object?> row) => Person(
            id: row['id'] as String,
            firstName: row['firstName'] as String,
            lastName: row['lastName'] as String,
            birthday: _dateTimeConverter.decode(row['birthday'] as int),
            allowedUnits:
                _listIntConverter.decode(row['allowedUnits'] as String),
            qualifications: _listQualificationConverter
                .decode(row['qualifications'] as String),
            updated: row['updated'] as int),
        arguments: [...ids]);
  }

  @override
  Future<void> inserts(Person person) async {
    await _personInsertionAdapter.insert(person, OnConflictStrategy.replace);
  }

  @override
  Future<void> updates(Person person) async {
    await _personUpdateAdapter.update(person, OnConflictStrategy.replace);
  }

  @override
  Future<void> deletes(Person person) async {
    await _personDeletionAdapter.delete(person);
  }
}

// ignore_for_file: unused_element
final _dateTimeConverter = DateTimeConverter();
final _listStringConverter = ListStringConverter();
final _listIntConverter = ListIntConverter();
final _nullableListIntConverter = NullableListIntConverter();
final _mapIntAlarmResponseConverter = MapIntAlarmResponseConverter();
final _alarmResponseConverter = AlarmResponseConverter();
final _listUnitPositionConverter = ListUnitPositionConverter();
final _listQualificationConverter = ListQualificationConverter();
