// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class ItemMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('abstract_items', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('description', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('abstract_items');
  }
}

class AssetMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('abstract_assets', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('description', length: 255);
      table.varChar('name', length: 255);
      table.double('price');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('abstract_assets', cascade: true);
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class ItemQuery extends Query<Item, ItemQueryWhere> {
  ItemQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = ItemQueryWhere(this);
  }

  @override
  final ItemQueryValues values = ItemQueryValues();

  List<String> _selectedFields = [];

  ItemQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'abstract_items';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'description',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  ItemQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  ItemQueryWhere? get where {
    return _where;
  }

  @override
  ItemQueryWhere newWhereClause() {
    return ItemQueryWhere(this);
  }

  Optional<Item> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Item(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      description: fields.contains('description') ? (row[3] as String) : '',
    );
    return Optional.of(model);
  }

  @override
  Optional<Item> deserialize(List row) {
    return parseRow(row);
  }
}

class ItemQueryWhere extends QueryWhere {
  ItemQueryWhere(ItemQuery query)
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
        description = StringSqlExpressionBuilder(
          query,
          'description',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder description;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      description,
    ];
  }
}

class ItemQueryValues extends MapQueryValues {
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

  String get description {
    return (values['description'] as String);
  }

  set description(String value) => values['description'] = value;

  void copyFrom(Item model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    description = model.description;
  }
}

class AssetQuery extends Query<Asset, AssetQueryWhere> {
  AssetQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = AssetQueryWhere(this);
    leftJoin(
      _items = ItemQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'asset_id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'description',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final AssetQueryValues values = AssetQueryValues();

  List<String> _selectedFields = [];

  AssetQueryWhere? _where;

  late ItemQuery _items;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'abstract_assets';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'description',
      'name',
      'price',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  AssetQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  AssetQueryWhere? get where {
    return _where;
  }

  @override
  AssetQueryWhere newWhereClause() {
    return AssetQueryWhere(this);
  }

  Optional<Asset> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Asset(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      description: fields.contains('description') ? (row[3] as String) : '',
      name: fields.contains('name') ? (row[4] as String) : '',
      price: fields.contains('price') ? mapToDouble(row[5]) : 0.0,
    );
    if (row.length > 6) {
      var modelOpt = ItemQuery().parseRow(row.skip(6).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(items: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Asset> deserialize(List row) {
    return parseRow(row);
  }

  ItemQuery get items {
    return _items;
  }

  @override
  Future<List<Asset>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<Asset>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                items: List<AbstractItem>.from(l.items)..addAll(model.items));
        }
      });
    });
  }

  @override
  Future<List<Asset>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<Asset>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                items: List<AbstractItem>.from(l.items)..addAll(model.items));
        }
      });
    });
  }

  @override
  Future<List<Asset>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<Asset>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                items: List<AbstractItem>.from(l.items)..addAll(model.items));
        }
      });
    });
  }
}

class AssetQueryWhere extends QueryWhere {
  AssetQueryWhere(AssetQuery query)
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
        description = StringSqlExpressionBuilder(
          query,
          'description',
        ),
        name = StringSqlExpressionBuilder(
          query,
          'name',
        ),
        price = NumericSqlExpressionBuilder<double>(
          query,
          'price',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder description;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<double> price;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      description,
      name,
      price,
    ];
  }
}

class AssetQueryValues extends MapQueryValues {
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

  String get description {
    return (values['description'] as String);
  }

  set description(String value) => values['description'] = value;

  String get name {
    return (values['name'] as String);
  }

  set name(String value) => values['name'] = value;

  double get price {
    return (values['price'] as double?) ?? 0.0;
  }

  set price(double value) => values['price'] = value;

  void copyFrom(Asset model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    description = model.description;
    name = model.name;
    price = model.price;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Item extends AbstractItem {
  Item({
    this.id,
    this.createdAt,
    this.updatedAt,
    required this.description,
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
  String description;

  Item copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
  }) {
    return Item(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        description: description ?? this.description);
  }

  @override
  bool operator ==(other) {
    return other is AbstractItem &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.description == description;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      description,
    ]);
  }

  @override
  String toString() {
    return 'Item(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, description=$description)';
  }

  Map<String, dynamic> toJson() {
    return ItemSerializer.toMap(this);
  }
}

@generatedSerializable
class Asset extends AbstractAsset {
  Asset({
    this.id,
    this.createdAt,
    this.updatedAt,
    required this.description,
    required this.name,
    required this.price,
    List<AbstractItem> items = const [],
  }) : items = List.unmodifiable(items);

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
  String description;

  @override
  String name;

  @override
  double price;

  @override
  List<AbstractItem> items;

  Asset copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? name,
    double? price,
    List<AbstractItem>? items,
  }) {
    return Asset(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        description: description ?? this.description,
        name: name ?? this.name,
        price: price ?? this.price,
        items: items ?? this.items);
  }

  @override
  bool operator ==(other) {
    return other is AbstractAsset &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.description == description &&
        other.name == name &&
        other.price == price &&
        ListEquality<AbstractItem>(DefaultEquality<AbstractItem>())
            .equals(other.items, items);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      description,
      name,
      price,
      items,
    ]);
  }

  @override
  String toString() {
    return 'Asset(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, description=$description, name=$name, price=$price, items=$items)';
  }

  Map<String, dynamic> toJson() {
    return AssetSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const ItemSerializer itemSerializer = ItemSerializer();

class ItemEncoder extends Converter<Item, Map> {
  const ItemEncoder();

  @override
  Map convert(Item model) => ItemSerializer.toMap(model);
}

class ItemDecoder extends Converter<Map, Item> {
  const ItemDecoder();

  @override
  Item convert(Map map) => ItemSerializer.fromMap(map);
}

class ItemSerializer extends Codec<Item, Map> {
  const ItemSerializer();

  @override
  ItemEncoder get encoder => const ItemEncoder();

  @override
  ItemDecoder get decoder => const ItemDecoder();

  static Item fromMap(Map map) {
    return Item(
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
        description: map['description'] as String);
  }

  static Map<String, dynamic> toMap(AbstractItem? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'description': model.description
    };
  }
}

abstract class ItemFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    description,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String description = 'description';
}

const AssetSerializer assetSerializer = AssetSerializer();

class AssetEncoder extends Converter<Asset, Map> {
  const AssetEncoder();

  @override
  Map convert(Asset model) => AssetSerializer.toMap(model);
}

class AssetDecoder extends Converter<Map, Asset> {
  const AssetDecoder();

  @override
  Asset convert(Map map) => AssetSerializer.fromMap(map);
}

class AssetSerializer extends Codec<Asset, Map> {
  const AssetSerializer();

  @override
  AssetEncoder get encoder => const AssetEncoder();

  @override
  AssetDecoder get decoder => const AssetDecoder();

  static Asset fromMap(Map map) {
    return Asset(
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
        description: map['description'] as String,
        name: map['name'] as String,
        price: map['price'] as double,
        items: map['items'] is Iterable
            ? List.unmodifiable(((map['items'] as Iterable).whereType<Map>())
                .map(ItemSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(AbstractAsset? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'description': model.description,
      'name': model.name,
      'price': model.price,
      'items': model.items.map((m) => ItemSerializer.toMap(m)).toList()
    };
  }
}

abstract class AssetFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    description,
    name,
    price,
    items,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String description = 'description';

  static const String name = 'name';

  static const String price = 'price';

  static const String items = 'items';
}
