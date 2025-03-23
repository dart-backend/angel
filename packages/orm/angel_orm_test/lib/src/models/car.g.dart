// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class CarMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'cars',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.varChar(
          'make',
          length: 255,
        );
        table.varChar(
          'description',
          length: 255,
        );
        table.boolean('family_friendly');
        table.timeStamp('recalled_at');
        table.double('price');
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('cars');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class CarQuery extends Query<Car, CarQueryWhere> {
  CarQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = CarQueryWhere(this);
  }

  @override
  final CarQueryValues values = CarQueryValues();

  List<String> _selectedFields = [];

  CarQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'cars';
  }

  @override
  List<String> get fields {
    const fields = [
      'id',
      'created_at',
      'updated_at',
      'make',
      'description',
      'family_friendly',
      'recalled_at',
      'price',
    ];
    return _selectedFields.isEmpty
        ? fields
        : fields.where((field) => _selectedFields.contains(field)).toList();
  }

  CarQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  CarQueryWhere? get where {
    return _where;
  }

  @override
  CarQueryWhere newWhereClause() {
    return CarQueryWhere(this);
  }

  Optional<Car> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Car(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      make: fields.contains('make') ? (row[3] as String?) : null,
      description: fields.contains('description') ? (row[4] as String?) : null,
      familyFriendly:
          fields.contains('family_friendly') ? mapToBool(row[5]) : null,
      recalledAt:
          fields.contains('recalled_at') ? mapToNullableDateTime(row[6]) : null,
      price: fields.contains('price') ? mapToDouble(row[7]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Car> deserialize(List row) {
    return parseRow(row);
  }
}

class CarQueryWhere extends QueryWhere {
  CarQueryWhere(CarQuery query)
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
        make = StringSqlExpressionBuilder(
          query,
          'make',
        ),
        description = StringSqlExpressionBuilder(
          query,
          'description',
        ),
        familyFriendly = BooleanSqlExpressionBuilder(
          query,
          'family_friendly',
        ),
        recalledAt = DateTimeSqlExpressionBuilder(
          query,
          'recalled_at',
        ),
        price = NumericSqlExpressionBuilder<double>(
          query,
          'price',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder make;

  final StringSqlExpressionBuilder description;

  final BooleanSqlExpressionBuilder familyFriendly;

  final DateTimeSqlExpressionBuilder recalledAt;

  final NumericSqlExpressionBuilder<double> price;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      make,
      description,
      familyFriendly,
      recalledAt,
      price,
    ];
  }
}

class CarQueryValues extends MapQueryValues {
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
  String? get make {
    return (values['make'] as String?);
  }

  set make(String? value) => values['make'] = value;
  String? get description {
    return (values['description'] as String?);
  }

  set description(String? value) => values['description'] = value;
  bool? get familyFriendly {
    return (values['family_friendly'] as bool?);
  }

  set familyFriendly(bool? value) => values['family_friendly'] = value;
  DateTime? get recalledAt {
    return (values['recalled_at'] as DateTime?);
  }

  set recalledAt(DateTime? value) => values['recalled_at'] = value;
  double? get price {
    return (values['price'] as double?) ?? 0.0;
  }

  set price(double? value) => values['price'] = value;
  void copyFrom(Car model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    make = model.make;
    description = model.description;
    familyFriendly = model.familyFriendly;
    recalledAt = model.recalledAt;
    price = model.price;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Car extends _Car {
  Car({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.make,
    this.description,
    this.familyFriendly,
    this.recalledAt,
    this.price,
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
  String? make;

  @override
  String? description;

  @override
  bool? familyFriendly;

  @override
  DateTime? recalledAt;

  @override
  double? price;

  Car copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? make,
    String? description,
    bool? familyFriendly,
    DateTime? recalledAt,
    double? price,
  }) {
    return Car(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        make: make ?? this.make,
        description: description ?? this.description,
        familyFriendly: familyFriendly ?? this.familyFriendly,
        recalledAt: recalledAt ?? this.recalledAt,
        price: price ?? this.price);
  }

  @override
  bool operator ==(other) {
    return other is _Car &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.make == make &&
        other.description == description &&
        other.familyFriendly == familyFriendly &&
        other.recalledAt == recalledAt &&
        other.price == price;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      make,
      description,
      familyFriendly,
      recalledAt,
      price,
    ]);
  }

  @override
  String toString() {
    return 'Car(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, make=$make, description=$description, familyFriendly=$familyFriendly, recalledAt=$recalledAt, price=$price)';
  }

  Map<String, dynamic> toJson() {
    return CarSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const CarSerializer carSerializer = CarSerializer();

class CarEncoder extends Converter<Car, Map> {
  const CarEncoder();

  @override
  Map convert(Car model) => CarSerializer.toMap(model);
}

class CarDecoder extends Converter<Map, Car> {
  const CarDecoder();

  @override
  Car convert(Map map) => CarSerializer.fromMap(map);
}

class CarSerializer extends Codec<Car, Map> {
  const CarSerializer();

  @override
  CarEncoder get encoder => const CarEncoder();
  @override
  CarDecoder get decoder => const CarDecoder();
  static Car fromMap(Map map) {
    return Car(
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
        make: map['make'] as String?,
        description: map['description'] as String?,
        familyFriendly: map['family_friendly'] as bool?,
        recalledAt: map['recalled_at'] != null
            ? (map['recalled_at'] is DateTime
                ? (map['recalled_at'] as DateTime)
                : DateTime.parse(map['recalled_at'].toString()))
            : null,
        price: map['price'] as double?);
  }

  static Map<String, dynamic> toMap(_Car? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'make': model.make,
      'description': model.description,
      'family_friendly': model.familyFriendly,
      'recalled_at': model.recalledAt?.toIso8601String(),
      'price': model.price
    };
  }
}

abstract class CarFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    make,
    description,
    familyFriendly,
    recalledAt,
    price,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String make = 'make';

  static const String description = 'description';

  static const String familyFriendly = 'family_friendly';

  static const String recalledAt = 'recalled_at';

  static const String price = 'price';
}
