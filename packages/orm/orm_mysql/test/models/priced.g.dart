// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'priced.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class PricedMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('priceds', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.numeric('amount', precision: 10, scale: 2);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('priceds');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class PricedQuery extends Query<Priced, PricedQueryWhere> {
  PricedQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = PricedQueryWhere(this);
  }

  @override
  final PricedQueryValues values = PricedQueryValues();

  List<String> _selectedFields = [];

  PricedQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'priceds';
  }

  @override
  List<String> get fields {
    const localFields = ['id', 'created_at', 'updated_at', 'amount'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  PricedQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  PricedQueryWhere? get where {
    return _where;
  }

  @override
  PricedQueryWhere newWhereClause() {
    return PricedQueryWhere(this);
  }

  Optional<Priced> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Priced(
      id: fields.contains('id') ? row[fields.indexOf('id')].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      amount: fields.contains('amount')
          ? mapToDouble(row[fields.indexOf('amount')])
          : 0.0,
    );
    return Optional.of(model);
  }

  @override
  Optional<Priced> deserialize(List row) {
    return parseRow(row);
  }
}

class PricedQueryWhere extends QueryWhere {
  PricedQueryWhere(PricedQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      amount = NumericSqlExpressionBuilder<double>(query, 'amount');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final NumericSqlExpressionBuilder<double> amount;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, amount];
  }
}

class PricedQueryValues extends MapQueryValues {
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

  double get amount {
    return (values['amount'] as double?) ?? 0.0;
  }

  set amount(double value) => values['amount'] = value;

  void copyFrom(Priced model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    amount = model.amount;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Priced extends PricedEntity {
  Priced({this.id, this.createdAt, this.updatedAt, required this.amount});

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
  double amount;

  Priced copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? amount,
  }) {
    return Priced(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      amount: amount ?? this.amount,
    );
  }

  @override
  bool operator ==(other) {
    return other is PricedEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.amount == amount;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, amount]);
  }

  @override
  String toString() {
    return 'Priced(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, amount=$amount)';
  }

  Map<String, dynamic> toJson() {
    return PricedSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const PricedSerializer pricedSerializer = PricedSerializer();

class PricedEncoder extends Converter<Priced, Map> {
  const PricedEncoder();

  @override
  Map convert(Priced model) => PricedSerializer.toMap(model);
}

class PricedDecoder extends Converter<Map, Priced> {
  const PricedDecoder();

  @override
  Priced convert(Map map) => PricedSerializer.fromMap(map);
}

class PricedSerializer extends Codec<Priced, Map> {
  const PricedSerializer();

  @override
  PricedEncoder get encoder => const PricedEncoder();

  @override
  PricedDecoder get decoder => const PricedDecoder();

  static Priced fromMap(Map map) {
    return Priced(
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
      amount: map['amount'] as double,
    );
  }

  static Map<String, dynamic> toMap(PricedEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'amount': model.amount,
    };
  }
}

abstract class PricedFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    amount,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String amount = 'amount';
}
