// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'has_map.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class HasMapMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('has_maps', (table) {
      table.declareColumn(
        'value',
        Column(type: ColumnType('jsonb'), length: 255),
      );
      table.declareColumn(
        'list',
        Column(type: ColumnType('jsonb'), length: 255),
      );
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('has_maps');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class HasMapQuery extends Query<HasMap, HasMapQueryWhere> {
  HasMapQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = HasMapQueryWhere(this);
  }

  @override
  final HasMapQueryValues values = HasMapQueryValues();

  List<String> _selectedFields = [];

  HasMapQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'has_maps';
  }

  @override
  List<String> get fields {
    const localFields = ['value', 'list'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  HasMapQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  HasMapQueryWhere? get where {
    return _where;
  }

  @override
  HasMapQueryWhere newWhereClause() {
    return HasMapQueryWhere(this);
  }

  Optional<HasMap> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = HasMap(
      value: fields.contains('value')
          ? (row[0] as Map<dynamic, dynamic>?)
          : null,
      list: fields.contains('list') ? (row[1] as List<dynamic>?) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<HasMap> deserialize(List row) {
    return parseRow(row);
  }
}

class HasMapQueryWhere extends QueryWhere {
  HasMapQueryWhere(HasMapQuery query)
    : value = MapSqlExpressionBuilder(query, 'value'),
      list = ListSqlExpressionBuilder(query, 'list');

  final MapSqlExpressionBuilder value;

  final ListSqlExpressionBuilder list;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [value, list];
  }
}

class HasMapQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {'list': 'jsonb'};
  }

  Map<dynamic, dynamic>? get value {
    return (values['value'] as Map<dynamic, dynamic>?);
  }

  set value(Map<dynamic, dynamic>? value) => values['value'] = value;

  List<dynamic>? get list {
    return json.decode((values['list'] as String)).cast();
  }

  set list(List<dynamic>? value) => values['list'] = json.encode(value);

  void copyFrom(HasMap model) {
    value = model.value;
    list = model.list;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class HasMap implements HasMapEntity {
  HasMap({this.value, this.list = const []});

  @override
  Map<dynamic, dynamic>? value;

  @override
  List<dynamic>? list;

  HasMap copyWith({Map<dynamic, dynamic>? value, List<dynamic>? list}) {
    return HasMap(value: value ?? this.value, list: list ?? this.list);
  }

  @override
  bool operator ==(other) {
    return other is HasMapEntity &&
        MapEquality<dynamic, dynamic>(
          keys: DefaultEquality(),
          values: DefaultEquality(),
        ).equals(other.value, value) &&
        ListEquality<dynamic>(DefaultEquality()).equals(other.list, list);
  }

  @override
  int get hashCode {
    return hashObjects([value, list]);
  }

  @override
  String toString() {
    return 'HasMap(value=$value, list=$list)';
  }

  Map<String, dynamic> toJson() {
    return HasMapSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const HasMapSerializer hasMapSerializer = HasMapSerializer();

class HasMapEncoder extends Converter<HasMap, Map> {
  const HasMapEncoder();

  @override
  Map convert(HasMap model) => HasMapSerializer.toMap(model);
}

class HasMapDecoder extends Converter<Map, HasMap> {
  const HasMapDecoder();

  @override
  HasMap convert(Map map) => HasMapSerializer.fromMap(map);
}

class HasMapSerializer extends Codec<HasMap, Map> {
  const HasMapSerializer();

  @override
  HasMapEncoder get encoder => const HasMapEncoder();

  @override
  HasMapDecoder get decoder => const HasMapDecoder();

  static HasMap fromMap(Map map) {
    return HasMap(
      value: map['value'] is Map
          ? (map['value'] as Map).cast<dynamic, dynamic>()
          : {},
      list: map['list'] is Iterable
          ? (map['list'] as Iterable).cast<dynamic>().toList()
          : [],
    );
  }

  static Map<String, dynamic> toMap(HasMapEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'value': model.value, 'list': model.list};
  }
}

abstract class HasMapFields {
  static const List<String> allFields = <String>[value, list];

  static const String value = 'value';

  static const String list = 'list';
}
