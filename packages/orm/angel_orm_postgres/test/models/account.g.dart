// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class AccountMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('accounts', (table) {
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
    schema.drop('accounts', cascade: true);
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class AccountQuery extends Query<Account, AccountQueryWhere> {
  AccountQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = AccountQueryWhere(this);
    leftJoin(
      _assets = AssetQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'account_id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'description',
        'name',
        'price',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final AccountQueryValues values = AccountQueryValues();

  List<String> _selectedFields = [];

  AccountQueryWhere? _where;

  late AssetQuery _assets;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'accounts';
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

  AccountQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  AccountQueryWhere? get where {
    return _where;
  }

  @override
  AccountQueryWhere newWhereClause() {
    return AccountQueryWhere(this);
  }

  Optional<Account> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Account(
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
      var modelOpt = AssetQuery().parseRow(row.skip(6).take(6).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(assets: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Account> deserialize(List row) {
    return parseRow(row);
  }

  AssetQuery get assets {
    return _assets;
  }

  @override
  Future<List<Account>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<Account>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                assets: List<AssetEntity>.from(l.assets)..addAll(model.assets));
        }
      });
    });
  }

  @override
  Future<List<Account>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<Account>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                assets: List<AssetEntity>.from(l.assets)..addAll(model.assets));
        }
      });
    });
  }

  @override
  Future<List<Account>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<Account>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                assets: List<AssetEntity>.from(l.assets)..addAll(model.assets));
        }
      });
    });
  }
}

class AccountQueryWhere extends QueryWhere {
  AccountQueryWhere(AccountQuery query)
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

class AccountQueryValues extends MapQueryValues {
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

  void copyFrom(Account model) {
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
class Account extends AccountEntity {
  Account({
    this.id,
    this.createdAt,
    this.updatedAt,
    required this.description,
    required this.name,
    required this.price,
    List<AssetEntity> assets = const [],
  }) : assets = List.unmodifiable(assets);

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
  List<AssetEntity> assets;

  Account copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? name,
    double? price,
    List<AssetEntity>? assets,
  }) {
    return Account(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        description: description ?? this.description,
        name: name ?? this.name,
        price: price ?? this.price,
        assets: assets ?? this.assets);
  }

  @override
  bool operator ==(other) {
    return other is AccountEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.description == description &&
        other.name == name &&
        other.price == price &&
        ListEquality<AssetEntity>(DefaultEquality<AssetEntity>())
            .equals(other.assets, assets);
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
      assets,
    ]);
  }

  @override
  String toString() {
    return 'Account(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, description=$description, name=$name, price=$price, assets=$assets)';
  }

  Map<String, dynamic> toJson() {
    return AccountSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const AccountSerializer accountSerializer = AccountSerializer();

class AccountEncoder extends Converter<Account, Map> {
  const AccountEncoder();

  @override
  Map convert(Account model) => AccountSerializer.toMap(model);
}

class AccountDecoder extends Converter<Map, Account> {
  const AccountDecoder();

  @override
  Account convert(Map map) => AccountSerializer.fromMap(map);
}

class AccountSerializer extends Codec<Account, Map> {
  const AccountSerializer();

  @override
  AccountEncoder get encoder => const AccountEncoder();

  @override
  AccountDecoder get decoder => const AccountDecoder();

  static Account fromMap(Map map) {
    return Account(
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
        assets: map['assets'] is Iterable
            ? List.unmodifiable(((map['assets'] as Iterable).whereType<Map>())
                .map(AssetSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(AccountEntity? model) {
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
      'assets': model.assets.map((m) => AssetSerializer.toMap(m)).toList()
    };
  }
}

abstract class AccountFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    description,
    name,
    price,
    assets,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String description = 'description';

  static const String name = 'name';

  static const String price = 'price';

  static const String assets = 'assets';
}
