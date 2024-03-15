// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetUnitCollection on Isar {
  IsarCollection<Unit> get units => this.collection();
}

const UnitSchema = CollectionSchema(
  name: r'Unit',
  id: 5852079958688209740,
  properties: {
    r'capacity': PropertySchema(
      id: 0,
      name: r'capacity',
      type: IsarType.long,
    ),
    r'positions': PropertySchema(
      id: 1,
      name: r'positions',
      type: IsarType.byteList,
      enumMap: _UnitpositionsEnumValueMap,
    ),
    r'stationId': PropertySchema(
      id: 2,
      name: r'stationId',
      type: IsarType.long,
    ),
    r'status': PropertySchema(
      id: 3,
      name: r'status',
      type: IsarType.long,
    ),
    r'unitDescription': PropertySchema(
      id: 4,
      name: r'unitDescription',
      type: IsarType.string,
    ),
    r'unitIdentifier': PropertySchema(
      id: 5,
      name: r'unitIdentifier',
      type: IsarType.long,
    ),
    r'unitType': PropertySchema(
      id: 6,
      name: r'unitType',
      type: IsarType.long,
    ),
    r'updated': PropertySchema(
      id: 7,
      name: r'updated',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _unitEstimateSize,
  serialize: _unitSerialize,
  deserialize: _unitDeserialize,
  deserializeProp: _unitDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _unitGetId,
  getLinks: _unitGetLinks,
  attach: _unitAttach,
  version: '3.1.0+1',
);

int _unitEstimateSize(
  Unit object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.positions.length;
  bytesCount += 3 + object.unitDescription.length * 3;
  return bytesCount;
}

void _unitSerialize(
  Unit object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.capacity);
  writer.writeByteList(
      offsets[1], object.positions.map((e) => e.index).toList());
  writer.writeLong(offsets[2], object.stationId);
  writer.writeLong(offsets[3], object.status);
  writer.writeString(offsets[4], object.unitDescription);
  writer.writeLong(offsets[5], object.unitIdentifier);
  writer.writeLong(offsets[6], object.unitType);
  writer.writeDateTime(offsets[7], object.updated);
}

Unit _unitDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Unit(
    capacity: reader.readLong(offsets[0]),
    id: id,
    positions: reader
            .readByteList(offsets[1])
            ?.map((e) => _UnitpositionsValueEnumMap[e] ?? UnitPosition.ma)
            .toList() ??
        [],
    stationId: reader.readLong(offsets[2]),
    status: reader.readLong(offsets[3]),
    unitDescription: reader.readString(offsets[4]),
    unitIdentifier: reader.readLong(offsets[5]),
    unitType: reader.readLong(offsets[6]),
    updated: reader.readDateTime(offsets[7]),
  );
  return object;
}

P _unitDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader
              .readByteList(offset)
              ?.map((e) => _UnitpositionsValueEnumMap[e] ?? UnitPosition.ma)
              .toList() ??
          []) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _UnitpositionsEnumValueMap = {
  'ma': 0,
  'gf': 1,
  'atf': 2,
  'atm': 3,
  'wtf': 4,
  'wtm': 5,
  'stf': 6,
  'stm': 7,
  'me': 8,
};
const _UnitpositionsValueEnumMap = {
  0: UnitPosition.ma,
  1: UnitPosition.gf,
  2: UnitPosition.atf,
  3: UnitPosition.atm,
  4: UnitPosition.wtf,
  5: UnitPosition.wtm,
  6: UnitPosition.stf,
  7: UnitPosition.stm,
  8: UnitPosition.me,
};

Id _unitGetId(Unit object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _unitGetLinks(Unit object) {
  return [];
}

void _unitAttach(IsarCollection<dynamic> col, Id id, Unit object) {}

extension UnitQueryWhereSort on QueryBuilder<Unit, Unit, QWhere> {
  QueryBuilder<Unit, Unit, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension UnitQueryWhere on QueryBuilder<Unit, Unit, QWhereClause> {
  QueryBuilder<Unit, Unit, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Unit, Unit, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension UnitQueryFilter on QueryBuilder<Unit, Unit, QFilterCondition> {
  QueryBuilder<Unit, Unit, QAfterFilterCondition> capacityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'capacity',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> capacityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'capacity',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> capacityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'capacity',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> capacityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'capacity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsElementEqualTo(
      UnitPosition value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'positions',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsElementGreaterThan(
    UnitPosition value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'positions',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsElementLessThan(
    UnitPosition value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'positions',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsElementBetween(
    UnitPosition lower,
    UnitPosition upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'positions',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'positions',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'positions',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'positions',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'positions',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'positions',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> positionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'positions',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> stationIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stationId',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> stationIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stationId',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> stationIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stationId',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> stationIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> statusEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> statusGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> statusLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> statusBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unitDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unitDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unitDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unitDescription',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'unitDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'unitDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'unitDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'unitDescription',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unitDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitDescriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'unitDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitIdentifierEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unitIdentifier',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitIdentifierGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unitIdentifier',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitIdentifierLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unitIdentifier',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitIdentifierBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unitIdentifier',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitTypeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unitType',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitTypeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unitType',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitTypeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unitType',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> unitTypeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unitType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> updatedEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updated',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> updatedGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updated',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> updatedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updated',
        value: value,
      ));
    });
  }

  QueryBuilder<Unit, Unit, QAfterFilterCondition> updatedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updated',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension UnitQueryObject on QueryBuilder<Unit, Unit, QFilterCondition> {}

extension UnitQueryLinks on QueryBuilder<Unit, Unit, QFilterCondition> {}

extension UnitQuerySortBy on QueryBuilder<Unit, Unit, QSortBy> {
  QueryBuilder<Unit, Unit, QAfterSortBy> sortByCapacity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capacity', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByCapacityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capacity', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByStationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stationId', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByStationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stationId', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUnitDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitDescription', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUnitDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitDescription', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUnitIdentifier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitIdentifier', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUnitIdentifierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitIdentifier', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUnitType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitType', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUnitTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitType', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> sortByUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated', Sort.desc);
    });
  }
}

extension UnitQuerySortThenBy on QueryBuilder<Unit, Unit, QSortThenBy> {
  QueryBuilder<Unit, Unit, QAfterSortBy> thenByCapacity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capacity', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByCapacityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capacity', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByStationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stationId', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByStationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stationId', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUnitDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitDescription', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUnitDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitDescription', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUnitIdentifier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitIdentifier', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUnitIdentifierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitIdentifier', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUnitType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitType', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUnitTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitType', Sort.desc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated', Sort.asc);
    });
  }

  QueryBuilder<Unit, Unit, QAfterSortBy> thenByUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated', Sort.desc);
    });
  }
}

extension UnitQueryWhereDistinct on QueryBuilder<Unit, Unit, QDistinct> {
  QueryBuilder<Unit, Unit, QDistinct> distinctByCapacity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'capacity');
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByPositions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'positions');
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByStationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stationId');
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByUnitDescription(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitDescription',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByUnitIdentifier() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitIdentifier');
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByUnitType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitType');
    });
  }

  QueryBuilder<Unit, Unit, QDistinct> distinctByUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updated');
    });
  }
}

extension UnitQueryProperty on QueryBuilder<Unit, Unit, QQueryProperty> {
  QueryBuilder<Unit, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Unit, int, QQueryOperations> capacityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'capacity');
    });
  }

  QueryBuilder<Unit, List<UnitPosition>, QQueryOperations> positionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'positions');
    });
  }

  QueryBuilder<Unit, int, QQueryOperations> stationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stationId');
    });
  }

  QueryBuilder<Unit, int, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<Unit, String, QQueryOperations> unitDescriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitDescription');
    });
  }

  QueryBuilder<Unit, int, QQueryOperations> unitIdentifierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitIdentifier');
    });
  }

  QueryBuilder<Unit, int, QQueryOperations> unitTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitType');
    });
  }

  QueryBuilder<Unit, DateTime, QQueryOperations> updatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updated');
    });
  }
}
