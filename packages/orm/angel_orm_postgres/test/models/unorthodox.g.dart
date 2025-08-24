// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unorthodox.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UnorthodoxMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('unorthodoxes', (table) {
      table.varChar('name', length: 255).primaryKey();
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('unorthodoxes');
  }
}

class WeirdJoinMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('weird_joins', (table) {
      table.integer('id').primaryKey();
      table
          .declare('join_name', ColumnType('varchar'))
          .references('unorthodoxes', 'name');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('weird_joins', cascade: true);
  }
}

class SongMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('songs', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.integer('weird_join_id');
      table.varChar('title', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('songs');
  }
}

class NumbaMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('numbas', (table) {
      table.integer('i');
      table.integer('parent');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('numbas');
  }
}

class FooMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('foos', (table) {
      table.varChar('bar', length: 255).primaryKey();
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('foos', cascade: true);
  }
}

class FooPivotMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('foo_pivots', (table) {
      table
          .declare('weird_join_id', ColumnType('int'))
          .references('weird_joins', 'id');
      table.declare('foo_bar', ColumnType('varchar')).references('foos', 'bar');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('foo_pivots');
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Unorthodox implements UnorthodoxEntity {
  Unorthodox({this.name});

  @override
  String? name;

  Unorthodox copyWith({String? name}) {
    return Unorthodox(name: name ?? this.name);
  }

  @override
  bool operator ==(other) {
    return other is UnorthodoxEntity && other.name == name;
  }

  @override
  int get hashCode {
    return hashObjects([name]);
  }

  @override
  String toString() {
    return 'Unorthodox(name=$name)';
  }

  Map<String, dynamic> toJson() {
    return UnorthodoxSerializer.toMap(this);
  }
}

@generatedSerializable
class WeirdJoin implements WeirdJoinEntity {
  WeirdJoin({
    required this.id,
    this.unorthodox,
    this.song,
    this.numbas = const [],
    this.foos = const [],
  });

  @override
  int id;

  @override
  UnorthodoxEntity? unorthodox;

  @override
  SongEntity? song;

  @override
  List<NumbaEntity> numbas;

  @override
  List<FooEntity> foos;

  WeirdJoin copyWith({
    int? id,
    UnorthodoxEntity? unorthodox,
    SongEntity? song,
    List<NumbaEntity>? numbas,
    List<FooEntity>? foos,
  }) {
    return WeirdJoin(
      id: id ?? this.id,
      unorthodox: unorthodox ?? this.unorthodox,
      song: song ?? this.song,
      numbas: numbas ?? this.numbas,
      foos: foos ?? this.foos,
    );
  }

  @override
  bool operator ==(other) {
    return other is WeirdJoinEntity &&
        other.id == id &&
        other.unorthodox == unorthodox &&
        other.song == song &&
        ListEquality<NumbaEntity>(
          DefaultEquality<NumbaEntity>(),
        ).equals(other.numbas, numbas) &&
        ListEquality<FooEntity>(
          DefaultEquality<FooEntity>(),
        ).equals(other.foos, foos);
  }

  @override
  int get hashCode {
    return hashObjects([id, unorthodox, song, numbas, foos]);
  }

  @override
  String toString() {
    return 'WeirdJoin(id=$id, unorthodox=$unorthodox, song=$song, numbas=$numbas, foos=$foos)';
  }

  Map<String, dynamic> toJson() {
    return WeirdJoinSerializer.toMap(this);
  }
}

@generatedSerializable
class Song extends SongEntity {
  Song({this.id, this.createdAt, this.updatedAt, this.weirdJoinId, this.title});

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
  int? weirdJoinId;

  @override
  String? title;

  Song copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? weirdJoinId,
    String? title,
  }) {
    return Song(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      weirdJoinId: weirdJoinId ?? this.weirdJoinId,
      title: title ?? this.title,
    );
  }

  @override
  bool operator ==(other) {
    return other is SongEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.weirdJoinId == weirdJoinId &&
        other.title == title;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, weirdJoinId, title]);
  }

  @override
  String toString() {
    return 'Song(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, weirdJoinId=$weirdJoinId, title=$title)';
  }

  Map<String, dynamic> toJson() {
    return SongSerializer.toMap(this);
  }
}

@generatedSerializable
class Numba extends NumbaEntity {
  Numba({this.i, this.parent});

  @override
  int? i;

  @override
  int? parent;

  Numba copyWith({int? i, int? parent}) {
    return Numba(i: i ?? this.i, parent: parent ?? this.parent);
  }

  @override
  bool operator ==(other) {
    return other is NumbaEntity && other.i == i && other.parent == parent;
  }

  @override
  int get hashCode {
    return hashObjects([i, parent]);
  }

  @override
  String toString() {
    return 'Numba(i=$i, parent=$parent)';
  }

  Map<String, dynamic> toJson() {
    return NumbaSerializer.toMap(this);
  }
}

@generatedSerializable
class Foo implements FooEntity {
  Foo({this.bar, this.weirdJoins = const []});

  @override
  String? bar;

  @override
  List<WeirdJoinEntity> weirdJoins;

  Foo copyWith({String? bar, List<WeirdJoinEntity>? weirdJoins}) {
    return Foo(bar: bar ?? this.bar, weirdJoins: weirdJoins ?? this.weirdJoins);
  }

  @override
  bool operator ==(other) {
    return other is FooEntity &&
        other.bar == bar &&
        ListEquality<WeirdJoinEntity>(
          DefaultEquality<WeirdJoinEntity>(),
        ).equals(other.weirdJoins, weirdJoins);
  }

  @override
  int get hashCode {
    return hashObjects([bar, weirdJoins]);
  }

  @override
  String toString() {
    return 'Foo(bar=$bar, weirdJoins=$weirdJoins)';
  }

  Map<String, dynamic> toJson() {
    return FooSerializer.toMap(this);
  }
}

@generatedSerializable
class FooPivot implements FooPivotEntity {
  FooPivot({this.weirdJoin, this.foo});

  @override
  WeirdJoinEntity? weirdJoin;

  @override
  FooEntity? foo;

  FooPivot copyWith({WeirdJoinEntity? weirdJoin, FooEntity? foo}) {
    return FooPivot(
      weirdJoin: weirdJoin ?? this.weirdJoin,
      foo: foo ?? this.foo,
    );
  }

  @override
  bool operator ==(other) {
    return other is FooPivotEntity &&
        other.weirdJoin == weirdJoin &&
        other.foo == foo;
  }

  @override
  int get hashCode {
    return hashObjects([weirdJoin, foo]);
  }

  @override
  String toString() {
    return 'FooPivot(weirdJoin=$weirdJoin, foo=$foo)';
  }

  Map<String, dynamic> toJson() {
    return FooPivotSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const UnorthodoxSerializer unorthodoxSerializer = UnorthodoxSerializer();

class UnorthodoxEncoder extends Converter<Unorthodox, Map> {
  const UnorthodoxEncoder();

  @override
  Map convert(Unorthodox model) => UnorthodoxSerializer.toMap(model);
}

class UnorthodoxDecoder extends Converter<Map, Unorthodox> {
  const UnorthodoxDecoder();

  @override
  Unorthodox convert(Map map) => UnorthodoxSerializer.fromMap(map);
}

class UnorthodoxSerializer extends Codec<Unorthodox, Map> {
  const UnorthodoxSerializer();

  @override
  UnorthodoxEncoder get encoder => const UnorthodoxEncoder();

  @override
  UnorthodoxDecoder get decoder => const UnorthodoxDecoder();

  static Unorthodox fromMap(Map map) {
    return Unorthodox(name: map['name'] as String?);
  }

  static Map<String, dynamic> toMap(UnorthodoxEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'name': model.name};
  }
}

abstract class UnorthodoxFields {
  static const List<String> allFields = <String>[name];

  static const String name = 'name';
}

const WeirdJoinSerializer weirdJoinSerializer = WeirdJoinSerializer();

class WeirdJoinEncoder extends Converter<WeirdJoin, Map> {
  const WeirdJoinEncoder();

  @override
  Map convert(WeirdJoin model) => WeirdJoinSerializer.toMap(model);
}

class WeirdJoinDecoder extends Converter<Map, WeirdJoin> {
  const WeirdJoinDecoder();

  @override
  WeirdJoin convert(Map map) => WeirdJoinSerializer.fromMap(map);
}

class WeirdJoinSerializer extends Codec<WeirdJoin, Map> {
  const WeirdJoinSerializer();

  @override
  WeirdJoinEncoder get encoder => const WeirdJoinEncoder();

  @override
  WeirdJoinDecoder get decoder => const WeirdJoinDecoder();

  static WeirdJoin fromMap(Map map) {
    return WeirdJoin(
      id: map['id'] as int,
      unorthodox: map['unorthodox'] != null
          ? UnorthodoxSerializer.fromMap(map['unorthodox'] as Map)
          : null,
      song: map['song'] != null
          ? SongSerializer.fromMap(map['song'] as Map)
          : null,
      numbas: map['numbas'] is Iterable
          ? List.unmodifiable(
              ((map['numbas'] as Iterable).whereType<Map>()).map(
                NumbaSerializer.fromMap,
              ),
            )
          : [],
      foos: map['foos'] is Iterable
          ? List.unmodifiable(
              ((map['foos'] as Iterable).whereType<Map>()).map(
                FooSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  static Map<String, dynamic> toMap(WeirdJoinEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'unorthodox': UnorthodoxSerializer.toMap(model.unorthodox),
      'song': SongSerializer.toMap(model.song),
      'numbas': model.numbas.map((m) => NumbaSerializer.toMap(m)).toList(),
      'foos': model.foos.map((m) => FooSerializer.toMap(m)).toList(),
    };
  }
}

abstract class WeirdJoinFields {
  static const List<String> allFields = <String>[
    id,
    unorthodox,
    song,
    numbas,
    foos,
  ];

  static const String id = 'id';

  static const String unorthodox = 'unorthodox';

  static const String song = 'song';

  static const String numbas = 'numbas';

  static const String foos = 'foos';
}

const SongSerializer songSerializer = SongSerializer();

class SongEncoder extends Converter<Song, Map> {
  const SongEncoder();

  @override
  Map convert(Song model) => SongSerializer.toMap(model);
}

class SongDecoder extends Converter<Map, Song> {
  const SongDecoder();

  @override
  Song convert(Map map) => SongSerializer.fromMap(map);
}

class SongSerializer extends Codec<Song, Map> {
  const SongSerializer();

  @override
  SongEncoder get encoder => const SongEncoder();

  @override
  SongDecoder get decoder => const SongDecoder();

  static Song fromMap(Map map) {
    return Song(
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
      weirdJoinId: map['weird_join_id'] as int?,
      title: map['title'] as String?,
    );
  }

  static Map<String, dynamic> toMap(SongEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'weird_join_id': model.weirdJoinId,
      'title': model.title,
    };
  }
}

abstract class SongFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    weirdJoinId,
    title,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String weirdJoinId = 'weird_join_id';

  static const String title = 'title';
}

const NumbaSerializer numbaSerializer = NumbaSerializer();

class NumbaEncoder extends Converter<Numba, Map> {
  const NumbaEncoder();

  @override
  Map convert(Numba model) => NumbaSerializer.toMap(model);
}

class NumbaDecoder extends Converter<Map, Numba> {
  const NumbaDecoder();

  @override
  Numba convert(Map map) => NumbaSerializer.fromMap(map);
}

class NumbaSerializer extends Codec<Numba, Map> {
  const NumbaSerializer();

  @override
  NumbaEncoder get encoder => const NumbaEncoder();

  @override
  NumbaDecoder get decoder => const NumbaDecoder();

  static Numba fromMap(Map map) {
    return Numba(i: map['i'] as int?, parent: map['parent'] as int?);
  }

  static Map<String, dynamic> toMap(NumbaEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'i': model.i, 'parent': model.parent};
  }
}

abstract class NumbaFields {
  static const List<String> allFields = <String>[i, parent];

  static const String i = 'i';

  static const String parent = 'parent';
}

const FooSerializer fooSerializer = FooSerializer();

class FooEncoder extends Converter<Foo, Map> {
  const FooEncoder();

  @override
  Map convert(Foo model) => FooSerializer.toMap(model);
}

class FooDecoder extends Converter<Map, Foo> {
  const FooDecoder();

  @override
  Foo convert(Map map) => FooSerializer.fromMap(map);
}

class FooSerializer extends Codec<Foo, Map> {
  const FooSerializer();

  @override
  FooEncoder get encoder => const FooEncoder();

  @override
  FooDecoder get decoder => const FooDecoder();

  static Foo fromMap(Map map) {
    return Foo(
      bar: map['bar'] as String?,
      weirdJoins: map['weird_joins'] is Iterable
          ? List.unmodifiable(
              ((map['weird_joins'] as Iterable).whereType<Map>()).map(
                WeirdJoinSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  static Map<String, dynamic> toMap(FooEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'bar': model.bar,
      'weird_joins': model.weirdJoins
          .map((m) => WeirdJoinSerializer.toMap(m))
          .toList(),
    };
  }
}

abstract class FooFields {
  static const List<String> allFields = <String>[bar, weirdJoins];

  static const String bar = 'bar';

  static const String weirdJoins = 'weird_joins';
}

const FooPivotSerializer fooPivotSerializer = FooPivotSerializer();

class FooPivotEncoder extends Converter<FooPivot, Map> {
  const FooPivotEncoder();

  @override
  Map convert(FooPivot model) => FooPivotSerializer.toMap(model);
}

class FooPivotDecoder extends Converter<Map, FooPivot> {
  const FooPivotDecoder();

  @override
  FooPivot convert(Map map) => FooPivotSerializer.fromMap(map);
}

class FooPivotSerializer extends Codec<FooPivot, Map> {
  const FooPivotSerializer();

  @override
  FooPivotEncoder get encoder => const FooPivotEncoder();

  @override
  FooPivotDecoder get decoder => const FooPivotDecoder();

  static FooPivot fromMap(Map map) {
    return FooPivot(
      weirdJoin: map['weird_join'] != null
          ? WeirdJoinSerializer.fromMap(map['weird_join'] as Map)
          : null,
      foo: map['foo'] != null ? FooSerializer.fromMap(map['foo'] as Map) : null,
    );
  }

  static Map<String, dynamic> toMap(FooPivotEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'weird_join': WeirdJoinSerializer.toMap(model.weirdJoin),
      'foo': FooSerializer.toMap(model.foo),
    };
  }
}

abstract class FooPivotFields {
  static const List<String> allFields = <String>[weirdJoin, foo];

  static const String weirdJoin = 'weird_join';

  static const String foo = 'foo';
}
