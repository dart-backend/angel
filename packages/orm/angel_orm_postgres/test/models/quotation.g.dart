// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quotation.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class QuotationMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('quotations', (table) {
      table.varChar('id', length: 255).primaryKey();
      table.varChar('name', length: 255);
      table.double('price');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('quotations');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class QuotationQuery extends Query<Quotation, QuotationQueryWhere> {
  QuotationQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = QuotationQueryWhere(this);
  }

  @override
  final QuotationQueryValues values = QuotationQueryValues();

  List<String> _selectedFields = [];

  QuotationQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'quotations';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'name',
      'price',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  QuotationQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  QuotationQueryWhere? get where {
    return _where;
  }

  @override
  QuotationQueryWhere newWhereClause() {
    return QuotationQueryWhere(this);
  }

  Optional<Quotation> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Quotation(
      id: fields.contains('id') ? (row[0] as String?) : null,
      name: fields.contains('name') ? (row[1] as String?) : null,
      price: fields.contains('price') ? mapToDouble(row[2]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Quotation> deserialize(List row) {
    return parseRow(row);
  }
}

class QuotationQueryWhere extends QueryWhere {
  QuotationQueryWhere(QuotationQuery query)
      : id = StringSqlExpressionBuilder(
          query,
          'id',
        ),
        name = StringSqlExpressionBuilder(
          query,
          'name',
        ),
        price = NumericSqlExpressionBuilder<double>(
          query,
          'price',
        );

  final StringSqlExpressionBuilder id;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<double> price;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      name,
      price,
    ];
  }
}

class QuotationQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get id {
    return (values['id'] as String?);
  }

  set id(String? value) => values['id'] = value;

  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;

  double? get price {
    return (values['price'] as double?) ?? 0.0;
  }

  set price(double? value) => values['price'] = value;

  void copyFrom(Quotation model) {
    id = model.id;
    name = model.name;
    price = model.price;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Quotation implements _Quotation {
  Quotation({
    this.id,
    this.name,
    this.price,
  });

  @override
  String? id;

  @override
  String? name;

  @override
  double? price;

  Quotation copyWith({
    String? id,
    String? name,
    double? price,
  }) {
    return Quotation(
        id: id ?? this.id, name: name ?? this.name, price: price ?? this.price);
  }

  @override
  bool operator ==(other) {
    return other is _Quotation &&
        other.id == id &&
        other.name == name &&
        other.price == price;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      name,
      price,
    ]);
  }

  @override
  String toString() {
    return 'Quotation(id=$id, name=$name, price=$price)';
  }

  Map<String, dynamic> toJson() {
    return QuotationSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const QuotationSerializer quotationSerializer = QuotationSerializer();

class QuotationEncoder extends Converter<Quotation, Map> {
  const QuotationEncoder();

  @override
  Map convert(Quotation model) => QuotationSerializer.toMap(model);
}

class QuotationDecoder extends Converter<Map, Quotation> {
  const QuotationDecoder();

  @override
  Quotation convert(Map map) => QuotationSerializer.fromMap(map);
}

class QuotationSerializer extends Codec<Quotation, Map> {
  const QuotationSerializer();

  @override
  QuotationEncoder get encoder => const QuotationEncoder();

  @override
  QuotationDecoder get decoder => const QuotationDecoder();

  static Quotation fromMap(Map map) {
    return Quotation(
        id: map['id'] as String?,
        name: map['name'] as String?,
        price: map['price'] as double?);
  }

  static Map<String, dynamic> toMap(_Quotation? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'id': model.id, 'name': model.name, 'price': model.price};
  }
}

abstract class QuotationFields {
  static const List<String> allFields = <String>[
    id,
    name,
    price,
  ];

  static const String id = 'id';

  static const String name = 'name';

  static const String price = 'price';
}
