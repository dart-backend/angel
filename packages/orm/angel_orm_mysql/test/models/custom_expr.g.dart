// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_expr.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class NumberMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('numbers', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('numbers');
  }
}

class AlphabetMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('alphabets', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('value', length: 255);
      table
          .declare('numbers_id', ColumnType('int'))
          .references('numbers', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('alphabets');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class NumberQuery extends Query<Number, NumberQueryWhere> {
  NumberQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    expressions['two'] = 'SELECT 2';
    _where = NumberQueryWhere(this);
  }

  @override
  final NumberQueryValues values = NumberQueryValues();

  List<String> _selectedFields = [];

  NumberQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'numbers';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'two',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  NumberQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  NumberQueryWhere? get where {
    return _where;
  }

  @override
  NumberQueryWhere newWhereClause() {
    return NumberQueryWhere(this);
  }

  Optional<Number> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Number(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      two: fields.contains('two') ? mapToInt(row[3]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Number> deserialize(List row) {
    return parseRow(row);
  }
}

class NumberQueryWhere extends QueryWhere {
  NumberQueryWhere(NumberQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        createdAt = DateTimeSqlExpressionBuilder(
          query,
          'created_at',
        ),
        updatedAt = DateTimeSqlExpressionBuilder(
          query,
          'updated_at',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
    ];
  }
}

class NumberQueryValues extends MapQueryValues {
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

  void copyFrom(Number model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
  }
}

class AlphabetQuery extends Query<Alphabet, AlphabetQueryWhere> {
  AlphabetQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = AlphabetQueryWhere(this);
    leftJoin(
      _numbers = NumberQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'numbers_id',
      'id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'two',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final AlphabetQueryValues values = AlphabetQueryValues();

  List<String> _selectedFields = [];

  AlphabetQueryWhere? _where;

  late NumberQuery _numbers;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'alphabets';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'value',
      'numbers_id',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  AlphabetQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  AlphabetQueryWhere? get where {
    return _where;
  }

  @override
  AlphabetQueryWhere newWhereClause() {
    return AlphabetQueryWhere(this);
  }

  Optional<Alphabet> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Alphabet(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      value: fields.contains('value') ? (row[3] as String?) : null,
    );
    if (row.length > 5) {
      var modelOpt = NumberQuery().parseRow(row.skip(5).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(numbers: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Alphabet> deserialize(List row) {
    return parseRow(row);
  }

  NumberQuery get numbers {
    return _numbers;
  }
}

class AlphabetQueryWhere extends QueryWhere {
  AlphabetQueryWhere(AlphabetQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        createdAt = DateTimeSqlExpressionBuilder(
          query,
          'created_at',
        ),
        updatedAt = DateTimeSqlExpressionBuilder(
          query,
          'updated_at',
        ),
        value = StringSqlExpressionBuilder(
          query,
          'value',
        ),
        numbersId = NumericSqlExpressionBuilder<int>(
          query,
          'numbers_id',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder value;

  final NumericSqlExpressionBuilder<int> numbersId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      value,
      numbersId,
    ];
  }
}

class AlphabetQueryValues extends MapQueryValues {
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

  String? get value {
    return (values['value'] as String?);
  }

  set value(String? value) => values['value'] = value;

  int get numbersId {
    return (values['numbers_id'] as int);
  }

  set numbersId(int value) => values['numbers_id'] = value;

  void copyFrom(Alphabet model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    value = model.value;
    if (model.numbers != null) {
      values['numbers_id'] = model.numbers?.id;
    }
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Number extends NumberEntity {
  Number({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.two,
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
  int? two;

  Number copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? two,
  }) {
    return Number(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        two: two ?? this.two);
  }

  @override
  bool operator ==(other) {
    return other is NumberEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.two == two;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      two,
    ]);
  }

  @override
  String toString() {
    return 'Number(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, two=$two)';
  }

  Map<String, dynamic> toJson() {
    return NumberSerializer.toMap(this);
  }
}

@generatedSerializable
class Alphabet extends AlphabetEntity {
  Alphabet({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.value,
    this.numbers,
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
  String? value;

  @override
  NumberEntity? numbers;

  Alphabet copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? value,
    NumberEntity? numbers,
  }) {
    return Alphabet(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        value: value ?? this.value,
        numbers: numbers ?? this.numbers);
  }

  @override
  bool operator ==(other) {
    return other is AlphabetEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.value == value &&
        other.numbers == numbers;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      value,
      numbers,
    ]);
  }

  @override
  String toString() {
    return 'Alphabet(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, value=$value, numbers=$numbers)';
  }

  Map<String, dynamic> toJson() {
    return AlphabetSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const NumberSerializer numberSerializer = NumberSerializer();

class NumberEncoder extends Converter<Number, Map> {
  const NumberEncoder();

  @override
  Map convert(Number model) => NumberSerializer.toMap(model);
}

class NumberDecoder extends Converter<Map, Number> {
  const NumberDecoder();

  @override
  Number convert(Map map) => NumberSerializer.fromMap(map);
}

class NumberSerializer extends Codec<Number, Map> {
  const NumberSerializer();

  @override
  NumberEncoder get encoder => const NumberEncoder();

  @override
  NumberDecoder get decoder => const NumberDecoder();

  static Number fromMap(Map map) {
    return Number(
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
        two: map['two'] as int?);
  }

  static Map<String, dynamic> toMap(NumberEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'two': model.two
    };
  }
}

abstract class NumberFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    two,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String two = 'two';
}

const AlphabetSerializer alphabetSerializer = AlphabetSerializer();

class AlphabetEncoder extends Converter<Alphabet, Map> {
  const AlphabetEncoder();

  @override
  Map convert(Alphabet model) => AlphabetSerializer.toMap(model);
}

class AlphabetDecoder extends Converter<Map, Alphabet> {
  const AlphabetDecoder();

  @override
  Alphabet convert(Map map) => AlphabetSerializer.fromMap(map);
}

class AlphabetSerializer extends Codec<Alphabet, Map> {
  const AlphabetSerializer();

  @override
  AlphabetEncoder get encoder => const AlphabetEncoder();

  @override
  AlphabetDecoder get decoder => const AlphabetDecoder();

  static Alphabet fromMap(Map map) {
    return Alphabet(
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
        value: map['value'] as String?,
        numbers: map['numbers'] != null
            ? NumberSerializer.fromMap(map['numbers'] as Map)
            : null);
  }

  static Map<String, dynamic> toMap(AlphabetEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'value': model.value,
      'numbers': NumberSerializer.toMap(model.numbers)
    };
  }
}

abstract class AlphabetFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    value,
    numbers,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String value = 'value';

  static const String numbers = 'numbers';
}
