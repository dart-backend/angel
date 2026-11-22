// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class PokemonMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('pokemons', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('species', length: 255);
      table.varChar('name', length: 255);
      table.integer('level');
      table.integer('type1');
      table.integer('type2');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('pokemons');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class PokemonQuery extends Query<Pokemon, PokemonQueryWhere> {
  PokemonQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = PokemonQueryWhere(this);
  }

  @override
  final PokemonQueryValues values = PokemonQueryValues();

  List<String> _selectedFields = [];

  PokemonQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'pokemons';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'species',
      'name',
      'level',
      'type1',
      'type2',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  PokemonQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  PokemonQueryWhere? get where {
    return _where;
  }

  @override
  PokemonQueryWhere newWhereClause() {
    return PokemonQueryWhere(this);
  }

  Optional<Pokemon> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Pokemon(
      id: fields.contains('id') ? row[fields.indexOf('id')].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      species: fields.contains('species')
          ? (row[fields.indexOf('species')] as String?)
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String?)
          : null,
      level: fields.contains('level')
          ? mapToInt(row[fields.indexOf('level')])
          : null,
      type1: fields.contains('type1')
          ? row[fields.indexOf('type1')] == null
                ? null
                : PokemonType.values[mapToInt(row[fields.indexOf('type1')])]
          : null,
      type2: fields.contains('type2')
          ? row[fields.indexOf('type2')] == null
                ? null
                : PokemonType.values[mapToInt(row[fields.indexOf('type2')])]
          : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Pokemon> deserialize(List row) {
    return parseRow(row);
  }
}

class PokemonQueryWhere extends QueryWhere {
  PokemonQueryWhere(PokemonQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      species = StringSqlExpressionBuilder(query, 'species'),
      name = StringSqlExpressionBuilder(query, 'name'),
      level = NumericSqlExpressionBuilder<int>(query, 'level'),
      type1 = EnumSqlExpressionBuilder<PokemonType?>(
        query,
        'type1',
        (v) => v?.index as int,
      ),
      type2 = EnumSqlExpressionBuilder<PokemonType?>(
        query,
        'type2',
        (v) => v?.index as int,
      );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder species;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<int> level;

  final EnumSqlExpressionBuilder<PokemonType?> type1;

  final EnumSqlExpressionBuilder<PokemonType?> type2;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, species, name, level, type1, type2];
  }
}

class PokemonQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get id {
    return (values['id'] as String?);
  }

  set id(String? value) => values['id'] = value;

  DateTime? get createdAt {
    return (values['created_at'] as DateTime?);
  }

  set createdAt(DateTime? value) => values['created_at'] = value;

  DateTime? get updatedAt {
    return (values['updated_at'] as DateTime?);
  }

  set updatedAt(DateTime? value) => values['updated_at'] = value;

  String? get species {
    return (values['species'] as String?);
  }

  set species(String? value) => values['species'] = value;

  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;

  int? get level {
    return (values['level'] as int?);
  }

  set level(int? value) => values['level'] = value;

  PokemonType? get type1 {
    return PokemonType.values[mapToInt(values['type1'])];
  }

  set type1(PokemonType? value) => values['type1'] = value?.index;

  PokemonType? get type2 {
    return PokemonType.values[mapToInt(values['type2'])];
  }

  set type2(PokemonType? value) => values['type2'] = value?.index;

  void copyFrom(Pokemon model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    species = model.species;
    name = model.name;
    level = model.level;
    type1 = model.type1;
    type2 = model.type2;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Pokemon extends _Pokemon {
  Pokemon({
    this.id,
    this.createdAt,
    this.updatedAt,
    required this.species,
    this.name,
    required this.level,
    required this.type1,
    this.type2,
  });

  /// A unique identifier corresponding to this item.
  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  @override
  String? species;

  @override
  String? name;

  @override
  int? level;

  @override
  PokemonType? type1;

  @override
  PokemonType? type2;

  Pokemon copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? species,
    String? name,
    int? level,
    PokemonType? type1,
    PokemonType? type2,
  }) {
    return Pokemon(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      species: species ?? this.species,
      name: name ?? this.name,
      level: level ?? this.level,
      type1: type1 ?? this.type1,
      type2: type2 ?? this.type2,
    );
  }

  @override
  bool operator ==(other) {
    return other is _Pokemon &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.species == species &&
        other.name == name &&
        other.level == level &&
        other.type1 == type1 &&
        other.type2 == type2;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      createdAt,
      updatedAt,
      species,
      name,
      level,
      type1,
      type2,
    ]);
  }

  @override
  String toString() {
    return 'Pokemon(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, species=$species, name=$name, level=$level, type1=$type1, type2=$type2)';
  }

  Map<String, dynamic> toJson() {
    return PokemonSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const PokemonSerializer pokemonSerializer = PokemonSerializer();

class PokemonEncoder extends Converter<Pokemon, Map> {
  const PokemonEncoder();

  @override
  Map convert(Pokemon model) => PokemonSerializer.toMap(model);
}

class PokemonDecoder extends Converter<Map, Pokemon> {
  const PokemonDecoder();

  @override
  Pokemon convert(Map map) => PokemonSerializer.fromMap(map);
}

class PokemonSerializer extends Codec<Pokemon, Map> {
  const PokemonSerializer();

  /// The name of the JSON Schema of [Pokemon].
  static const String schemaName = 'Pokemon';

  /// The JSON Schema of the map that [toMap] writes of [Pokemon], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'id': {
        'type': ['string', 'null'],
      },
      'created_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'updated_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'species': {'type': 'string'},
      'name': {
        'type': ['string', 'null'],
      },
      'level': {'type': 'integer'},
      'type1': {
        'type': 'integer',
        'enum': [0, 1, 2, 3, 4, 5, 6, 7, 8],
        'description': 'The index of PokemonType: fire, grass, water, dragon, poison, dark, fighting, electric, ghost',
      },
      'type2': {
        'type': ['integer', 'null'],
        'enum': [0, 1, 2, 3, 4, 5, 6, 7, 8, null],
        'description': 'The index of PokemonType: fire, grass, water, dragon, poison, dark, fighting, electric, ghost',
      },
    },
    'required': ['species', 'level', 'type1'],
  };

  @override
  PokemonEncoder get encoder => const PokemonEncoder();

  @override
  PokemonDecoder get decoder => const PokemonDecoder();

  static Pokemon fromMap(Map map) {
    if (map['species'] == null) {
      throw FormatException("Missing required field 'species' on Pokemon.");
    }

    if (map['level'] == null) {
      throw FormatException("Missing required field 'level' on Pokemon.");
    }

    if (map['type1'] == null) {
      throw FormatException("Missing required field 'type1' on Pokemon.");
    }

    return Pokemon(
      id: map['id'] as String?,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is DateTime
                ? (map['created_at'] as DateTime)
                : DateTime.parse(map['created_at'].toString()))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
                ? (map['updated_at'] as DateTime)
                : DateTime.parse(map['updated_at'].toString()))
          : null,
      species: map['species'] as String?,
      name: map['name'] as String?,
      level: map['level'] as int?,
      type1: map['type1'] is PokemonType
          ? map['type1'] as PokemonType
          : map['type1'] is String
          ? PokemonType.values.byName(map['type1'] as String)
          : map['type1'] is int
          ? PokemonType.values[map['type1'] as int]
          : null,
      type2: map['type2'] is PokemonType
          ? map['type2'] as PokemonType
          : map['type2'] is String
          ? PokemonType.values.byName(map['type2'] as String)
          : map['type2'] is int
          ? PokemonType.values[map['type2'] as int]
          : null,
    );
  }

  /// Adds the JSON Schema of [Pokemon], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(_Pokemon? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    if (model.species == null) {
      throw FormatException("Missing required field 'species' on Pokemon.");
    }

    if (model.level == null) {
      throw FormatException("Missing required field 'level' on Pokemon.");
    }

    if (model.type1 == null) {
      throw FormatException("Missing required field 'type1' on Pokemon.");
    }

    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'species': model.species,
      'name': model.name,
      'level': model.level,
      'type1': model.type1 == null
          ? null
          : PokemonType.values.indexOf(model.type1!),
      'type2': model.type2 == null
          ? null
          : PokemonType.values.indexOf(model.type2!),
    };
  }
}

abstract class PokemonFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    species,
    name,
    level,
    type1,
    type2,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String species = 'species';

  static const String name = 'name';

  static const String level = 'level';

  static const String type1 = 'type1';

  static const String type2 = 'type2';
}
