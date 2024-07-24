// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bike.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class BikeMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'bikes',
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
        table.integer('width');
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('bikes');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class BikeQuery extends Query<Bike, BikeQueryWhere> {
  BikeQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = BikeQueryWhere(this);
  }

  @override
  final BikeQueryValues values = BikeQueryValues();

  List<String> _selectedFields = [];

  BikeQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'bikes';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'make',
      'description',
      'family_friendly',
      'recalled_at',
      'price',
      'width',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  BikeQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  BikeQueryWhere? get where {
    return _where;
  }

  @override
  BikeQueryWhere newWhereClause() {
    return BikeQueryWhere(this);
  }

  Optional<Bike> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Bike(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      make: fields.contains('make') ? (row[3] as String) : '',
      description: fields.contains('description') ? (row[4] as String) : '',
      familyFriendly:
          fields.contains('family_friendly') ? mapToBool(row[5]) : false,
      recalledAt: fields.contains('recalled_at')
          ? mapToDateTime(row[6])
          : DateTime.parse("1970-01-01 00:00:00"),
      price: fields.contains('price') ? mapToDouble(row[7]) : 0.0,
      width: fields.contains('width') ? (row[8] as int) : 0,
    );
    return Optional.of(model);
  }

  @override
  Optional<Bike> deserialize(List row) {
    return parseRow(row);
  }
}

class BikeQueryWhere extends QueryWhere {
  BikeQueryWhere(BikeQuery query)
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
        ),
        width = NumericSqlExpressionBuilder<int>(
          query,
          'width',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder make;

  final StringSqlExpressionBuilder description;

  final BooleanSqlExpressionBuilder familyFriendly;

  final DateTimeSqlExpressionBuilder recalledAt;

  final NumericSqlExpressionBuilder<double> price;

  final NumericSqlExpressionBuilder<int> width;

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
      width,
    ];
  }
}

class BikeQueryValues extends MapQueryValues {
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

  String get make {
    return (values['make'] as String);
  }

  set make(String value) => values['make'] = value;

  String get description {
    return (values['description'] as String);
  }

  set description(String value) => values['description'] = value;

  bool get familyFriendly {
    return (values['family_friendly'] as bool);
  }

  set familyFriendly(bool value) => values['family_friendly'] = value;

  DateTime get recalledAt {
    return (values['recalled_at'] as DateTime);
  }

  set recalledAt(DateTime value) => values['recalled_at'] = value;

  double get price {
    return (values['price'] as double?) ?? 0.0;
  }

  set price(double value) => values['price'] = value;

  int get width {
    return (values['width'] as int);
  }

  set width(int value) => values['width'] = value;

  void copyFrom(Bike model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    make = model.make;
    description = model.description;
    familyFriendly = model.familyFriendly;
    recalledAt = model.recalledAt;
    price = model.price;
    width = model.width;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Bike extends _Bike {
  Bike({
    this.id,
    this.createdAt,
    this.updatedAt,
    required this.make,
    required this.description,
    required this.familyFriendly,
    required this.recalledAt,
    required this.price,
    required this.width,
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
  String make;

  @override
  String description;

  @override
  bool familyFriendly;

  @override
  DateTime recalledAt;

  @override
  double price;

  @override
  int width;

  Bike copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? make,
    String? description,
    bool? familyFriendly,
    DateTime? recalledAt,
    double? price,
    int? width,
  }) {
    return Bike(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        make: make ?? this.make,
        description: description ?? this.description,
        familyFriendly: familyFriendly ?? this.familyFriendly,
        recalledAt: recalledAt ?? this.recalledAt,
        price: price ?? this.price,
        width: width ?? this.width);
  }

  @override
  bool operator ==(other) {
    return other is _Bike &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.make == make &&
        other.description == description &&
        other.familyFriendly == familyFriendly &&
        other.recalledAt == recalledAt &&
        other.price == price &&
        other.width == width;
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
      width,
    ]);
  }

  @override
  String toString() {
    return 'Bike(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, make=$make, description=$description, familyFriendly=$familyFriendly, recalledAt=$recalledAt, price=$price, width=$width)';
  }

  Map<String, dynamic> toJson() {
    return BikeSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const BikeSerializer bikeSerializer = BikeSerializer();

class BikeEncoder extends Converter<Bike, Map> {
  const BikeEncoder();

  @override
  Map convert(Bike model) => BikeSerializer.toMap(model);
}

class BikeDecoder extends Converter<Map, Bike> {
  const BikeDecoder();

  @override
  Bike convert(Map map) => BikeSerializer.fromMap(map);
}

class BikeSerializer extends Codec<Bike, Map> {
  const BikeSerializer();

  @override
  BikeEncoder get encoder => const BikeEncoder();

  @override
  BikeDecoder get decoder => const BikeDecoder();

  static Bike fromMap(Map map) {
    return Bike(
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
        make: map['make'] as String,
        description: map['description'] as String,
        familyFriendly: map['family_friendly'] as bool,
        recalledAt: map['recalled_at'] != null
            ? (map['recalled_at'] is DateTime
                ? (map['recalled_at'] as DateTime)
                : DateTime.parse(map['recalled_at'].toString()))
            : DateTime.parse("1970-01-01 00:00:00"),
        price: map['price'] as double,
        width: map['width'] as int);
  }

  static Map<String, dynamic> toMap(_Bike? model) {
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
      'recalled_at': model.recalledAt.toIso8601String(),
      'price': model.price,
      'width': model.width
    };
  }
}

abstract class BikeFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    make,
    description,
    familyFriendly,
    recalledAt,
    price,
    width,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String make = 'make';

  static const String description = 'description';

  static const String familyFriendly = 'family_friendly';

  static const String recalledAt = 'recalled_at';

  static const String price = 'price';

  static const String width = 'width';
}
