// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class TreeMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'trees',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.integer('rings').unique();
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop(
      'trees',
      cascade: true,
    );
  }
}

class FruitMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'fruits',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.integer('tree_id');
        table.varChar(
          'common_name',
          length: 255,
        );
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('fruits');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class TreeQuery extends Query<Tree, TreeQueryWhere> {
  TreeQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = TreeQueryWhere(this);
    leftJoin(
      _fruits = FruitQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'tree_id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'tree_id',
        'common_name',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final TreeQueryValues values = TreeQueryValues();

  List<String> _selectedFields = [];

  TreeQueryWhere? _where;

  late FruitQuery _fruits;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'trees';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'rings',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  TreeQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  TreeQueryWhere? get where {
    return _where;
  }

  @override
  TreeQueryWhere newWhereClause() {
    return TreeQueryWhere(this);
  }

  Optional<Tree> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Tree(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      rings: fields.contains('rings') ? (row[3] as int?) : null,
    );
    if (row.length > 4) {
      var modelOpt = FruitQuery().parseRow(row.skip(4).take(5).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(fruits: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Tree> deserialize(List row) {
    return parseRow(row);
  }

  FruitQuery get fruits {
    return _fruits;
  }

  @override
  Future<List<Tree>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<Tree>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                fruits: List<_Fruit>.from(l.fruits)..addAll(model.fruits));
        }
      });
    });
  }

  @override
  Future<List<Tree>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<Tree>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                fruits: List<_Fruit>.from(l.fruits)..addAll(model.fruits));
        }
      });
    });
  }

  @override
  Future<List<Tree>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<Tree>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                fruits: List<_Fruit>.from(l.fruits)..addAll(model.fruits));
        }
      });
    });
  }
}

class TreeQueryWhere extends QueryWhere {
  TreeQueryWhere(TreeQuery query)
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
        rings = NumericSqlExpressionBuilder<int>(
          query,
          'rings',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final NumericSqlExpressionBuilder<int> rings;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      rings,
    ];
  }
}

class TreeQueryValues extends MapQueryValues {
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
  int? get rings {
    return (values['rings'] as int?);
  }

  set rings(int? value) => values['rings'] = value;
  void copyFrom(Tree model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    rings = model.rings;
  }
}

class FruitQuery extends Query<Fruit, FruitQueryWhere> {
  FruitQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = FruitQueryWhere(this);
  }

  @override
  final FruitQueryValues values = FruitQueryValues();

  List<String> _selectedFields = [];

  FruitQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'fruits';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'tree_id',
      'common_name',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  FruitQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  FruitQueryWhere? get where {
    return _where;
  }

  @override
  FruitQueryWhere newWhereClause() {
    return FruitQueryWhere(this);
  }

  Optional<Fruit> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Fruit(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      treeId: fields.contains('tree_id') ? (row[3] as int?) : null,
      commonName: fields.contains('common_name') ? (row[4] as String?) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Fruit> deserialize(List row) {
    return parseRow(row);
  }
}

class FruitQueryWhere extends QueryWhere {
  FruitQueryWhere(FruitQuery query)
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
        treeId = NumericSqlExpressionBuilder<int>(
          query,
          'tree_id',
        ),
        commonName = StringSqlExpressionBuilder(
          query,
          'common_name',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final NumericSqlExpressionBuilder<int> treeId;

  final StringSqlExpressionBuilder commonName;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      treeId,
      commonName,
    ];
  }
}

class FruitQueryValues extends MapQueryValues {
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
  int? get treeId {
    return (values['tree_id'] as int?);
  }

  set treeId(int? value) => values['tree_id'] = value;
  String? get commonName {
    return (values['common_name'] as String?);
  }

  set commonName(String? value) => values['common_name'] = value;
  void copyFrom(Fruit model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    treeId = model.treeId;
    commonName = model.commonName;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Tree extends _Tree {
  Tree({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.rings,
    List<_Fruit> fruits = const [],
  }) : fruits = List.unmodifiable(fruits);

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
  int? rings;

  @override
  List<_Fruit> fruits;

  Tree copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? rings,
    List<_Fruit>? fruits,
  }) {
    return Tree(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rings: rings ?? this.rings,
        fruits: fruits ?? this.fruits);
  }

  @override
  bool operator ==(other) {
    return other is _Tree &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.rings == rings &&
        ListEquality<_Fruit>(DefaultEquality<_Fruit>())
            .equals(other.fruits, fruits);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      rings,
      fruits,
    ]);
  }

  @override
  String toString() {
    return 'Tree(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, rings=$rings, fruits=$fruits)';
  }

  Map<String, dynamic> toJson() {
    return TreeSerializer.toMap(this);
  }
}

@generatedSerializable
class Fruit extends _Fruit {
  Fruit({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.treeId,
    this.commonName,
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
  int? treeId;

  @override
  String? commonName;

  Fruit copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? treeId,
    String? commonName,
  }) {
    return Fruit(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        treeId: treeId ?? this.treeId,
        commonName: commonName ?? this.commonName);
  }

  @override
  bool operator ==(other) {
    return other is _Fruit &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.treeId == treeId &&
        other.commonName == commonName;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      treeId,
      commonName,
    ]);
  }

  @override
  String toString() {
    return 'Fruit(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, treeId=$treeId, commonName=$commonName)';
  }

  Map<String, dynamic> toJson() {
    return FruitSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const TreeSerializer treeSerializer = TreeSerializer();

class TreeEncoder extends Converter<Tree, Map> {
  const TreeEncoder();

  @override
  Map convert(Tree model) => TreeSerializer.toMap(model);
}

class TreeDecoder extends Converter<Map, Tree> {
  const TreeDecoder();

  @override
  Tree convert(Map map) => TreeSerializer.fromMap(map);
}

class TreeSerializer extends Codec<Tree, Map> {
  const TreeSerializer();

  @override
  TreeEncoder get encoder => const TreeEncoder();
  @override
  TreeDecoder get decoder => const TreeDecoder();
  static Tree fromMap(Map map) {
    return Tree(
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
        rings: map['rings'] as int?,
        fruits: map['fruits'] is Iterable
            ? List.unmodifiable(((map['fruits'] as Iterable).whereType<Map>())
                .map(FruitSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_Tree? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'rings': model.rings,
      'fruits': model.fruits.map((m) => FruitSerializer.toMap(m)).toList()
    };
  }
}

abstract class TreeFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    rings,
    fruits,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String rings = 'rings';

  static const String fruits = 'fruits';
}

const FruitSerializer fruitSerializer = FruitSerializer();

class FruitEncoder extends Converter<Fruit, Map> {
  const FruitEncoder();

  @override
  Map convert(Fruit model) => FruitSerializer.toMap(model);
}

class FruitDecoder extends Converter<Map, Fruit> {
  const FruitDecoder();

  @override
  Fruit convert(Map map) => FruitSerializer.fromMap(map);
}

class FruitSerializer extends Codec<Fruit, Map> {
  const FruitSerializer();

  @override
  FruitEncoder get encoder => const FruitEncoder();
  @override
  FruitDecoder get decoder => const FruitDecoder();
  static Fruit fromMap(Map map) {
    return Fruit(
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
        treeId: map['tree_id'] as int?,
        commonName: map['common_name'] as String?);
  }

  static Map<String, dynamic> toMap(_Fruit? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'tree_id': model.treeId,
      'common_name': model.commonName
    };
  }
}

abstract class FruitFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    treeId,
    commonName,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String treeId = 'tree_id';

  static const String commonName = 'common_name';
}
