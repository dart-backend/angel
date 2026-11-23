// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uuid_user.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UuidUserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_users', (table) {
      table.declare('id', ColumnType.uuid).primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_users');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class UuidUserQuery extends Query<UuidUser, UuidUserQueryWhere> {
  UuidUserQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidUserQueryWhere(this);
  }

  @override
  final UuidUserQueryValues values = UuidUserQueryValues();

  List<String> _selectedFields = [];

  UuidUserQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_users';
  }

  @override
  List<String> get fields {
    const localFields = ['id', 'created_at', 'updated_at', 'name'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  UuidUserQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidUserQueryWhere? get where {
    return _where;
  }

  @override
  UuidUserQueryWhere newWhereClause() {
    return UuidUserQueryWhere(this);
  }

  Optional<UuidUser> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidUser(
      id: fields.contains('id') ? (row[fields.indexOf('id')] as String?) : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String?)
          : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<UuidUser> deserialize(List row) {
    return parseRow(row);
  }
}

class UuidUserQueryWhere extends QueryWhere {
  UuidUserQueryWhere(UuidUserQuery query)
    : id = StringSqlExpressionBuilder(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      name = StringSqlExpressionBuilder(query, 'name');

  final StringSqlExpressionBuilder id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name];
  }
}

class UuidUserQueryValues extends MapQueryValues {
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

  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;

  void copyFrom(UuidUser model) {
    id = model.id;
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class UuidUser extends UuidUserEntity {
  UuidUser({this.id, this.createdAt, this.updatedAt, this.name});

  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  @override
  String? name;

  UuidUser copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
  }) {
    return UuidUser(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidUserEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, name]);
  }

  @override
  String toString() {
    return 'UuidUser(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name)';
  }

  Map<String, dynamic> toJson() {
    return UuidUserSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const UuidUserSerializer uuidUserSerializer = UuidUserSerializer();

class UuidUserEncoder extends Converter<UuidUser, Map> {
  const UuidUserEncoder();

  @override
  Map convert(UuidUser model) => UuidUserSerializer.toMap(model);
}

class UuidUserDecoder extends Converter<Map, UuidUser> {
  const UuidUserDecoder();

  @override
  UuidUser convert(Map map) => UuidUserSerializer.fromMap(map);
}

class UuidUserSerializer extends Codec<UuidUser, Map> {
  const UuidUserSerializer();

  /// The name of the JSON Schema of [UuidUser].
  static const String schemaName = 'UuidUser';

  /// The JSON Schema of the map that [toMap] writes of [UuidUser], whose
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
      'name': {
        'type': ['string', 'null'],
      },
    },
  };

  @override
  UuidUserEncoder get encoder => const UuidUserEncoder();

  @override
  UuidUserDecoder get decoder => const UuidUserDecoder();

  static UuidUser fromMap(Map map) {
    return UuidUser(
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
      name: map['name'] as String?,
    );
  }

  /// Adds the JSON Schema of [UuidUser], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(UuidUserEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
    };
  }
}

abstract class UuidUserFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';
}
