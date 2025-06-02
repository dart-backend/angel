// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class PersonMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('persons', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
      table.integer('age');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('persons');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class PersonQuery extends Query<Person, PersonQueryWhere> {
  PersonQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = PersonQueryWhere(this);
  }

  @override
  final PersonQueryValues values = PersonQueryValues();

  List<String> _selectedFields = [];

  PersonQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'persons';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'name',
      'age',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  PersonQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  PersonQueryWhere? get where {
    return _where;
  }

  @override
  PersonQueryWhere newWhereClause() {
    return PersonQueryWhere(this);
  }

  Optional<Person> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Person(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      name: fields.contains('name') ? (row[3] as String?) : null,
      age: fields.contains('age') ? mapToInt(row[4]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Person> deserialize(List row) {
    return parseRow(row);
  }
}

class PersonQueryWhere extends QueryWhere {
  PersonQueryWhere(PersonQuery query)
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
        name = StringSqlExpressionBuilder(
          query,
          'name',
        ),
        age = NumericSqlExpressionBuilder<int>(
          query,
          'age',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<int> age;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      name,
      age,
    ];
  }
}

class PersonQueryValues extends MapQueryValues {
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

  int? get age {
    return (values['age'] as int?);
  }

  set age(int? value) => values['age'] = value;

  void copyFrom(Person model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
    age = model.age;
  }
}

class PersonWithLastOrderQuery
    extends Query<PersonWithLastOrder, PersonWithLastOrderQueryWhere> {
  PersonWithLastOrderQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    expressions['last_order_name'] = 'po.name';
    expressions['last_order_price'] = 'po.price';
    _where = PersonWithLastOrderQueryWhere(this);
  }

  @override
  final PersonWithLastOrderQueryValues values =
      PersonWithLastOrderQueryValues();

  List<String> _selectedFields = [];

  PersonWithLastOrderQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'persons';
  }

  @override
  List<String> get fields {
    const localFields = [
      'name',
      'last_order_name',
      'last_order_price',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  PersonWithLastOrderQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  PersonWithLastOrderQueryWhere? get where {
    return _where;
  }

  @override
  PersonWithLastOrderQueryWhere newWhereClause() {
    return PersonWithLastOrderQueryWhere(this);
  }

  Optional<PersonWithLastOrder> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = PersonWithLastOrder(
      name: fields.contains('name') ? (row[0] as String?) : null,
      lastOrderName:
          fields.contains('last_order_name') ? (row[1] as String?) : null,
      lastOrderPrice:
          fields.contains('last_order_price') ? mapToDouble(row[2]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<PersonWithLastOrder> deserialize(List row) {
    return parseRow(row);
  }
}

class PersonWithLastOrderQueryWhere extends QueryWhere {
  PersonWithLastOrderQueryWhere(PersonWithLastOrderQuery query)
      : name = StringSqlExpressionBuilder(
          query,
          'name',
        );

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [name];
  }
}

class PersonWithLastOrderQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;

  void copyFrom(PersonWithLastOrder model) {
    name = model.name;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Person extends _Person {
  Person({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    this.age,
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
  int? age;

  Person copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    int? age,
  }) {
    return Person(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name,
        age: age ?? this.age);
  }

  @override
  bool operator ==(other) {
    return other is _Person &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        other.age == age;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      name,
      age,
    ]);
  }

  @override
  String toString() {
    return 'Person(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, age=$age)';
  }

  Map<String, dynamic> toJson() {
    return PersonSerializer.toMap(this);
  }
}

@generatedSerializable
class PersonWithLastOrder extends _PersonWithLastOrder {
  PersonWithLastOrder({
    this.name,
    this.lastOrderName,
    this.lastOrderPrice,
  });

  @override
  String? name;

  @override
  String? lastOrderName;

  @override
  double? lastOrderPrice;

  PersonWithLastOrder copyWith({
    String? name,
    String? lastOrderName,
    double? lastOrderPrice,
  }) {
    return PersonWithLastOrder(
        name: name ?? this.name,
        lastOrderName: lastOrderName ?? this.lastOrderName,
        lastOrderPrice: lastOrderPrice ?? this.lastOrderPrice);
  }

  @override
  bool operator ==(other) {
    return other is _PersonWithLastOrder &&
        other.name == name &&
        other.lastOrderName == lastOrderName &&
        other.lastOrderPrice == lastOrderPrice;
  }

  @override
  int get hashCode {
    return hashObjects([
      name,
      lastOrderName,
      lastOrderPrice,
    ]);
  }

  @override
  String toString() {
    return 'PersonWithLastOrder(name=$name, lastOrderName=$lastOrderName, lastOrderPrice=$lastOrderPrice)';
  }

  Map<String, dynamic> toJson() {
    return PersonWithLastOrderSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const PersonSerializer personSerializer = PersonSerializer();

class PersonEncoder extends Converter<Person, Map> {
  const PersonEncoder();

  @override
  Map convert(Person model) => PersonSerializer.toMap(model);
}

class PersonDecoder extends Converter<Map, Person> {
  const PersonDecoder();

  @override
  Person convert(Map map) => PersonSerializer.fromMap(map);
}

class PersonSerializer extends Codec<Person, Map> {
  const PersonSerializer();

  @override
  PersonEncoder get encoder => const PersonEncoder();

  @override
  PersonDecoder get decoder => const PersonDecoder();

  static Person fromMap(Map map) {
    return Person(
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
        age: map['age'] as int?);
  }

  static Map<String, dynamic> toMap(_Person? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'age': model.age
    };
  }
}

abstract class PersonFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    age,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String age = 'age';
}

const PersonWithLastOrderSerializer personWithLastOrderSerializer =
    PersonWithLastOrderSerializer();

class PersonWithLastOrderEncoder extends Converter<PersonWithLastOrder, Map> {
  const PersonWithLastOrderEncoder();

  @override
  Map convert(PersonWithLastOrder model) =>
      PersonWithLastOrderSerializer.toMap(model);
}

class PersonWithLastOrderDecoder extends Converter<Map, PersonWithLastOrder> {
  const PersonWithLastOrderDecoder();

  @override
  PersonWithLastOrder convert(Map map) =>
      PersonWithLastOrderSerializer.fromMap(map);
}

class PersonWithLastOrderSerializer extends Codec<PersonWithLastOrder, Map> {
  const PersonWithLastOrderSerializer();

  @override
  PersonWithLastOrderEncoder get encoder => const PersonWithLastOrderEncoder();

  @override
  PersonWithLastOrderDecoder get decoder => const PersonWithLastOrderDecoder();

  static PersonWithLastOrder fromMap(Map map) {
    return PersonWithLastOrder(
        name: map['name'] as String?,
        lastOrderName: map['last_order_name'] as String?,
        lastOrderPrice: map['last_order_price'] as double?);
  }

  static Map<String, dynamic> toMap(_PersonWithLastOrder? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'name': model.name,
      'last_order_name': model.lastOrderName,
      'last_order_price': model.lastOrderPrice
    };
  }
}

abstract class PersonWithLastOrderFields {
  static const List<String> allFields = <String>[
    name,
    lastOrderName,
    lastOrderPrice,
  ];

  static const String name = 'name';

  static const String lastOrderName = 'last_order_name';

  static const String lastOrderPrice = 'last_order_price';
}
