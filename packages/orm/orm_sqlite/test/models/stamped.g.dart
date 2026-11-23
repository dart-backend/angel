// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stamped.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class StampedMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('stampeds', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
      table.timeStamp('seen_at').defaultsTo(const RawSql('CURRENT_TIMESTAMP'));
      table.varChar('code', length: 255).defaultsTo(const RawSql('\'n/a\''));
      table.varChar('label', length: 255).defaultsTo('plain');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('stampeds');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class StampedQuery extends Query<Stamped, StampedQueryWhere> {
  StampedQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = StampedQueryWhere(this);
  }

  @override
  final StampedQueryValues values = StampedQueryValues();

  List<String> _selectedFields = [];

  StampedQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'stampeds';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'name',
      'seen_at',
      'code',
      'label',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  StampedQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  StampedQueryWhere? get where {
    return _where;
  }

  @override
  StampedQueryWhere newWhereClause() {
    return StampedQueryWhere(this);
  }

  Optional<Stamped> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Stamped(
      id: fields.contains('id') ? row[fields.indexOf('id')].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String?)
          : null,
      seenAt: fields.contains('seen_at')
          ? mapToNullableDateTime(row[fields.indexOf('seen_at')])
          : null,
      code: fields.contains('code')
          ? (row[fields.indexOf('code')] as String?)
          : null,
      label: fields.contains('label')
          ? (row[fields.indexOf('label')] as String?)
          : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Stamped> deserialize(List row) {
    return parseRow(row);
  }
}

class StampedQueryWhere extends QueryWhere {
  StampedQueryWhere(StampedQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      name = StringSqlExpressionBuilder(query, 'name'),
      seenAt = DateTimeSqlExpressionBuilder(query, 'seen_at'),
      code = StringSqlExpressionBuilder(query, 'code'),
      label = StringSqlExpressionBuilder(query, 'label');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  final DateTimeSqlExpressionBuilder seenAt;

  final StringSqlExpressionBuilder code;

  final StringSqlExpressionBuilder label;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name, seenAt, code, label];
  }
}

class StampedQueryValues extends MapQueryValues {
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

  DateTime? get seenAt {
    return (values['seen_at'] as DateTime?);
  }

  set seenAt(DateTime? value) => values['seen_at'] = value;

  String? get code {
    return (values['code'] as String?);
  }

  set code(String? value) => values['code'] = value;

  String? get label {
    return (values['label'] as String?);
  }

  set label(String? value) => values['label'] = value;

  void copyFrom(Stamped model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
    seenAt = model.seenAt;
    code = model.code;
    label = model.label;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Stamped extends StampedEntity {
  Stamped({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    this.seenAt,
    this.code,
    this.label,
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
  String? name;

  @override
  DateTime? seenAt;

  @override
  String? code;

  @override
  String? label;

  Stamped copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    DateTime? seenAt,
    String? code,
    String? label,
  }) {
    return Stamped(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      seenAt: seenAt ?? this.seenAt,
      code: code ?? this.code,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(other) {
    return other is StampedEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        other.seenAt == seenAt &&
        other.code == code &&
        other.label == label;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      createdAt,
      updatedAt,
      name,
      seenAt,
      code,
      label,
    ]);
  }

  @override
  String toString() {
    return 'Stamped(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, seenAt=$seenAt, code=$code, label=$label)';
  }

  Map<String, dynamic> toJson() {
    return StampedSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const StampedSerializer stampedSerializer = StampedSerializer();

class StampedEncoder extends Converter<Stamped, Map> {
  const StampedEncoder();

  @override
  Map convert(Stamped model) => StampedSerializer.toMap(model);
}

class StampedDecoder extends Converter<Map, Stamped> {
  const StampedDecoder();

  @override
  Stamped convert(Map map) => StampedSerializer.fromMap(map);
}

class StampedSerializer extends Codec<Stamped, Map> {
  const StampedSerializer();

  /// The name of the JSON Schema of [Stamped].
  static const String schemaName = 'Stamped';

  /// The JSON Schema of the map that [toMap] writes of [Stamped], whose
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
      'seen_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'code': {
        'type': ['string', 'null'],
      },
      'label': {
        'type': ['string', 'null'],
      },
    },
  };

  @override
  StampedEncoder get encoder => const StampedEncoder();

  @override
  StampedDecoder get decoder => const StampedDecoder();

  static Stamped fromMap(Map map) {
    return Stamped(
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
      seenAt: map['seen_at'] != null
          ? (map['seen_at'] is DateTime
                ? (map['seen_at'] as DateTime)
                : DateTime.parse(map['seen_at'].toString()))
          : null,
      code: map['code'] as String?,
      label: map['label'] as String?,
    );
  }

  /// Adds the JSON Schema of [Stamped], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(StampedEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'seen_at': model.seenAt?.toIso8601String(),
      'code': model.code,
      'label': model.label,
    };
  }
}

abstract class StampedFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    seenAt,
    code,
    label,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String seenAt = 'seen_at';

  static const String code = 'code';

  static const String label = 'label';
}
