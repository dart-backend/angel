// GENERATED CODE - DO NOT MODIFY BY HAND

part of angel3_orm_generator.test.models.person_order;

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class PersonOrderMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('person_orders', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.integer('person_id');
      table.varChar('name', length: 255);
      table.declareColumn(
          'price', Column(type: ColumnType('decimal'), length: 255));
      table.boolean('deleted');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('person_orders');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class PersonOrderQuery extends Query<PersonOrder, PersonOrderQueryWhere> {
  PersonOrderQuery({Query? parent, Set<String>? trampoline})
      : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = PersonOrderQueryWhere(this);
  }

  @override
  final PersonOrderQueryValues values = PersonOrderQueryValues();

  List<String> _selectedFields = [];

  PersonOrderQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {'price': 'char'};
  }

  @override
  String get tableName {
    return 'person_orders';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'person_id',
      'name',
      'price',
      'deleted'
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  PersonOrderQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  PersonOrderQueryWhere? get where {
    return _where;
  }

  @override
  PersonOrderQueryWhere newWhereClause() {
    return PersonOrderQueryWhere(this);
  }

  Optional<PersonOrder> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = PersonOrder(
        id: fields.contains('id') ? row[0].toString() : null,
        createdAt: fields.contains('created_at') ? (row[1] as DateTime?) : null,
        updatedAt: fields.contains('updated_at') ? (row[2] as DateTime?) : null,
        personId: fields.contains('person_id') ? (row[3] as int?) : null,
        name: fields.contains('name') ? (row[4] as String?) : null,
        price: fields.contains('price')
            ? double.tryParse(row[5].toString())
            : null,
        deleted: fields.contains('deleted') ? (row[6] as bool?) : null);
    return Optional.of(model);
  }

  @override
  Optional<PersonOrder> deserialize(List row) {
    return parseRow(row);
  }
}

class PersonOrderQueryWhere extends QueryWhere {
  PersonOrderQueryWhere(PersonOrderQuery query)
      : id = NumericSqlExpressionBuilder<int>(query, 'id'),
        createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
        updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
        personId = NumericSqlExpressionBuilder<int>(query, 'person_id'),
        name = StringSqlExpressionBuilder(query, 'name'),
        price = NumericSqlExpressionBuilder<double>(query, 'price'),
        deleted = BooleanSqlExpressionBuilder(query, 'deleted');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final NumericSqlExpressionBuilder<int> personId;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<double> price;

  final BooleanSqlExpressionBuilder deleted;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, personId, name, price, deleted];
  }
}

class PersonOrderQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {'price': 'decimal'};
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
  int? get personId {
    return (values['person_id'] as int?);
  }

  set personId(int? value) => values['person_id'] = value;
  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;
  double? get price {
    return double.tryParse((values['price'] as String));
  }

  set price(double? value) => values['price'] = value.toString();
  bool? get deleted {
    return (values['deleted'] as bool?);
  }

  set deleted(bool? value) => values['deleted'] = value;
  void copyFrom(PersonOrder model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    personId = model.personId;
    name = model.name;
    price = model.price;
    deleted = model.deleted;
  }
}

class OrderWithPersonInfoQuery
    extends Query<OrderWithPersonInfo, OrderWithPersonInfoQueryWhere> {
  OrderWithPersonInfoQuery({Query? parent, Set<String>? trampoline})
      : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    expressions['person_name'] = 'p.name';
    expressions['person_age'] = 'p.age';
    _where = OrderWithPersonInfoQueryWhere(this);
  }

  @override
  final OrderWithPersonInfoQueryValues values =
      OrderWithPersonInfoQueryValues();

  List<String> _selectedFields = [];

  OrderWithPersonInfoQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {'price': 'char'};
  }

  @override
  String get tableName {
    return 'person_orders';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'name',
      'price',
      'deleted',
      'person_name',
      'person_age'
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  OrderWithPersonInfoQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  OrderWithPersonInfoQueryWhere? get where {
    return _where;
  }

  @override
  OrderWithPersonInfoQueryWhere newWhereClause() {
    return OrderWithPersonInfoQueryWhere(this);
  }

  Optional<OrderWithPersonInfo> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = OrderWithPersonInfo(
        id: fields.contains('id') ? row[0].toString() : null,
        createdAt: fields.contains('created_at') ? (row[1] as DateTime?) : null,
        updatedAt: fields.contains('updated_at') ? (row[2] as DateTime?) : null,
        name: fields.contains('name') ? (row[3] as String?) : null,
        price: fields.contains('price')
            ? double.tryParse(row[4].toString())
            : null,
        deleted: fields.contains('deleted') ? (row[5] as bool?) : null,
        personName: fields.contains('person_name') ? (row[6] as String?) : null,
        personAge: fields.contains('person_age') ? (row[7] as int?) : null);
    return Optional.of(model);
  }

  @override
  Optional<OrderWithPersonInfo> deserialize(List row) {
    return parseRow(row);
  }
}

class OrderWithPersonInfoQueryWhere extends QueryWhere {
  OrderWithPersonInfoQueryWhere(OrderWithPersonInfoQuery query)
      : id = NumericSqlExpressionBuilder<int>(query, 'id'),
        createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
        updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
        name = StringSqlExpressionBuilder(query, 'name'),
        price = NumericSqlExpressionBuilder<double>(query, 'price'),
        deleted = BooleanSqlExpressionBuilder(query, 'deleted');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<double> price;

  final BooleanSqlExpressionBuilder deleted;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name, price, deleted];
  }
}

class OrderWithPersonInfoQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {'price': 'decimal'};
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
  double? get price {
    return double.tryParse((values['price'] as String));
  }

  set price(double? value) => values['price'] = value.toString();
  bool? get deleted {
    return (values['deleted'] as bool?);
  }

  set deleted(bool? value) => values['deleted'] = value;
  void copyFrom(OrderWithPersonInfo model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
    price = model.price;
    deleted = model.deleted;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class PersonOrder extends _PersonOrder {
  PersonOrder(
      {this.id,
      this.createdAt,
      this.updatedAt,
      this.personId,
      this.name,
      this.price,
      this.deleted});

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
  int? personId;

  @override
  String? name;

  @override
  double? price;

  @override
  bool? deleted;

  PersonOrder copyWith(
      {String? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      int? personId,
      String? name,
      double? price,
      bool? deleted}) {
    return PersonOrder(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        personId: personId ?? this.personId,
        name: name ?? this.name,
        price: price ?? this.price,
        deleted: deleted ?? this.deleted);
  }

  @override
  bool operator ==(other) {
    return other is _PersonOrder &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.personId == personId &&
        other.name == name &&
        other.price == price &&
        other.deleted == deleted;
  }

  @override
  int get hashCode {
    return hashObjects(
        [id, createdAt, updatedAt, personId, name, price, deleted]);
  }

  @override
  String toString() {
    return 'PersonOrder(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, personId=$personId, name=$name, price=$price, deleted=$deleted)';
  }

  Map<String, dynamic> toJson() {
    return PersonOrderSerializer.toMap(this);
  }
}

@generatedSerializable
class OrderWithPersonInfo extends _OrderWithPersonInfo {
  OrderWithPersonInfo(
      {this.id,
      this.createdAt,
      this.updatedAt,
      this.name,
      this.price,
      this.deleted,
      this.personName,
      this.personAge});

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
  double? price;

  @override
  bool? deleted;

  @override
  String? personName;

  @override
  int? personAge;

  OrderWithPersonInfo copyWith(
      {String? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? name,
      double? price,
      bool? deleted,
      String? personName,
      int? personAge}) {
    return OrderWithPersonInfo(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name,
        price: price ?? this.price,
        deleted: deleted ?? this.deleted,
        personName: personName ?? this.personName,
        personAge: personAge ?? this.personAge);
  }

  @override
  bool operator ==(other) {
    return other is _OrderWithPersonInfo &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        other.price == price &&
        other.deleted == deleted &&
        other.personName == personName &&
        other.personAge == personAge;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      name,
      price,
      deleted,
      personName,
      personAge
    ]);
  }

  @override
  String toString() {
    return 'OrderWithPersonInfo(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, price=$price, deleted=$deleted, personName=$personName, personAge=$personAge)';
  }

  Map<String, dynamic> toJson() {
    return OrderWithPersonInfoSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const PersonOrderSerializer personOrderSerializer = PersonOrderSerializer();

class PersonOrderEncoder extends Converter<PersonOrder, Map> {
  const PersonOrderEncoder();

  @override
  Map convert(PersonOrder model) => PersonOrderSerializer.toMap(model);
}

class PersonOrderDecoder extends Converter<Map, PersonOrder> {
  const PersonOrderDecoder();

  @override
  PersonOrder convert(Map map) => PersonOrderSerializer.fromMap(map);
}

class PersonOrderSerializer extends Codec<PersonOrder, Map> {
  const PersonOrderSerializer();

  @override
  PersonOrderEncoder get encoder => const PersonOrderEncoder();
  @override
  PersonOrderDecoder get decoder => const PersonOrderDecoder();
  static PersonOrder fromMap(Map map) {
    return PersonOrder(
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
        personId: map['person_id'] as int?,
        name: map['name'] as String?,
        price: map['price'] as double?,
        deleted: map['deleted'] as bool?);
  }

  static Map<String, dynamic> toMap(_PersonOrder? model) {
    if (model == null) {
      return {};
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'person_id': model.personId,
      'name': model.name,
      'price': model.price,
      'deleted': model.deleted
    };
  }
}

abstract class PersonOrderFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    personId,
    name,
    price,
    deleted
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String personId = 'person_id';

  static const String name = 'name';

  static const String price = 'price';

  static const String deleted = 'deleted';
}

const OrderWithPersonInfoSerializer orderWithPersonInfoSerializer =
    OrderWithPersonInfoSerializer();

class OrderWithPersonInfoEncoder extends Converter<OrderWithPersonInfo, Map> {
  const OrderWithPersonInfoEncoder();

  @override
  Map convert(OrderWithPersonInfo model) =>
      OrderWithPersonInfoSerializer.toMap(model);
}

class OrderWithPersonInfoDecoder extends Converter<Map, OrderWithPersonInfo> {
  const OrderWithPersonInfoDecoder();

  @override
  OrderWithPersonInfo convert(Map map) =>
      OrderWithPersonInfoSerializer.fromMap(map);
}

class OrderWithPersonInfoSerializer extends Codec<OrderWithPersonInfo, Map> {
  const OrderWithPersonInfoSerializer();

  @override
  OrderWithPersonInfoEncoder get encoder => const OrderWithPersonInfoEncoder();
  @override
  OrderWithPersonInfoDecoder get decoder => const OrderWithPersonInfoDecoder();
  static OrderWithPersonInfo fromMap(Map map) {
    return OrderWithPersonInfo(
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
        price: map['price'] as double?,
        deleted: map['deleted'] as bool?,
        personName: map['person_name'] as String?,
        personAge: map['person_age'] as int?);
  }

  static Map<String, dynamic> toMap(_OrderWithPersonInfo? model) {
    if (model == null) {
      return {};
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'price': model.price,
      'deleted': model.deleted,
      'person_name': model.personName,
      'person_age': model.personAge
    };
  }
}

abstract class OrderWithPersonInfoFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    price,
    deleted,
    personName,
    personAge
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String price = 'price';

  static const String deleted = 'deleted';

  static const String personName = 'person_name';

  static const String personAge = 'person_age';
}
