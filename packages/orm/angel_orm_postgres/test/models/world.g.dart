// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'world.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class WorldMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('world', (table) {
      table.integer('id').primaryKey();
      table.integer('randomnumber');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('world');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class WorldQuery extends Query<World, WorldQueryWhere> {
  WorldQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = WorldQueryWhere(this);
  }

  @override
  final WorldQueryValues values = WorldQueryValues();

  List<String> _selectedFields = [];

  WorldQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'world';
  }

  @override
  List<String> get fields {
    const localFields = ['id', 'randomnumber'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  WorldQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  WorldQueryWhere? get where {
    return _where;
  }

  @override
  WorldQueryWhere newWhereClause() {
    return WorldQueryWhere(this);
  }

  Optional<World> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = World(
      id: fields.contains('id') ? mapToInt(row[0]) : null,
      randomnumber: fields.contains('randomnumber') ? mapToInt(row[1]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<World> deserialize(List row) {
    return parseRow(row);
  }
}

class WorldQueryWhere extends QueryWhere {
  WorldQueryWhere(WorldQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      randomnumber = NumericSqlExpressionBuilder<int>(query, 'randomnumber');

  final NumericSqlExpressionBuilder<int> id;

  final NumericSqlExpressionBuilder<int> randomnumber;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, randomnumber];
  }
}

class WorldQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int? get id {
    return (values['id'] as int?);
  }

  set id(int? value) => values['id'] = value;

  int? get randomnumber {
    return (values['randomnumber'] as int?);
  }

  set randomnumber(int? value) => values['randomnumber'] = value;

  void copyFrom(World model) {
    id = model.id;
    randomnumber = model.randomnumber;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class World extends WorldEntity {
  World({this.id, this.randomnumber});

  @override
  int? id;

  @override
  int? randomnumber;

  World copyWith({int? id, int? randomnumber}) {
    return World(
      id: id ?? this.id,
      randomnumber: randomnumber ?? this.randomnumber,
    );
  }

  @override
  bool operator ==(other) {
    return other is WorldEntity &&
        other.id == id &&
        other.randomnumber == randomnumber;
  }

  @override
  int get hashCode {
    return hashObjects([id, randomnumber]);
  }

  @override
  String toString() {
    return 'World(id=$id, randomnumber=$randomnumber)';
  }

  Map<String, dynamic> toJson() {
    return WorldSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const WorldSerializer worldSerializer = WorldSerializer();

class WorldEncoder extends Converter<World, Map> {
  const WorldEncoder();

  @override
  Map convert(World model) => WorldSerializer.toMap(model);
}

class WorldDecoder extends Converter<Map, World> {
  const WorldDecoder();

  @override
  World convert(Map map) => WorldSerializer.fromMap(map);
}

class WorldSerializer extends Codec<World, Map> {
  const WorldSerializer();

  @override
  WorldEncoder get encoder => const WorldEncoder();

  @override
  WorldDecoder get decoder => const WorldDecoder();

  static World fromMap(Map map) {
    return World(
      id: map['id'] as int?,
      randomnumber: map['randomnumber'] as int?,
    );
  }

  static Map<String, dynamic> toMap(WorldEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'id': model.id, 'randomnumber': model.randomnumber};
  }
}

abstract class WorldFields {
  static const List<String> allFields = <String>[id, randomnumber];

  static const String id = 'id';

  static const String randomnumber = 'randomnumber';
}
