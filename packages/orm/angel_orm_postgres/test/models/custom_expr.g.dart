// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_expr.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class NumberMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('numbers', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('numbers');
  }
}

class AlphabetMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('alphabets', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('value', length: 255);
      table
          .declare('numbers_id', ColumnType('int'))
          .references('numbers', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('alphabets');
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Number extends NumberEntity {
  Number({this.id, this.createdAt, this.updatedAt, this.two});

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
  int? two;

  Number copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? two,
  }) {
    return Number(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      two: two ?? this.two,
    );
  }

  @override
  bool operator ==(other) {
    return other is NumberEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.two == two;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, two]);
  }

  @override
  String toString() {
    return 'Number(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, two=$two)';
  }

  Map<String, dynamic> toJson() {
    return NumberSerializer.toMap(this);
  }
}

@generatedSerializable
class Alphabet extends AlphabetEntity {
  Alphabet({this.id, this.createdAt, this.updatedAt, this.value, this.numbers});

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
  String? value;

  @override
  NumberEntity? numbers;

  Alphabet copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? value,
    NumberEntity? numbers,
  }) {
    return Alphabet(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      value: value ?? this.value,
      numbers: numbers ?? this.numbers,
    );
  }

  @override
  bool operator ==(other) {
    return other is AlphabetEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.value == value &&
        other.numbers == numbers;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, value, numbers]);
  }

  @override
  String toString() {
    return 'Alphabet(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, value=$value, numbers=$numbers)';
  }

  Map<String, dynamic> toJson() {
    return AlphabetSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const NumberSerializer numberSerializer = NumberSerializer();

class NumberEncoder extends Converter<Number, Map> {
  const NumberEncoder();

  @override
  Map convert(Number model) => NumberSerializer.toMap(model);
}

class NumberDecoder extends Converter<Map, Number> {
  const NumberDecoder();

  @override
  Number convert(Map map) => NumberSerializer.fromMap(map);
}

class NumberSerializer extends Codec<Number, Map> {
  const NumberSerializer();

  @override
  NumberEncoder get encoder => const NumberEncoder();

  @override
  NumberDecoder get decoder => const NumberDecoder();

  static Number fromMap(Map map) {
    return Number(
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
      two: map['two'] as int?,
    );
  }

  static Map<String, dynamic> toMap(NumberEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'two': model.two,
    };
  }
}

abstract class NumberFields {
  static const List<String> allFields = <String>[id, createdAt, updatedAt, two];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String two = 'two';
}

const AlphabetSerializer alphabetSerializer = AlphabetSerializer();

class AlphabetEncoder extends Converter<Alphabet, Map> {
  const AlphabetEncoder();

  @override
  Map convert(Alphabet model) => AlphabetSerializer.toMap(model);
}

class AlphabetDecoder extends Converter<Map, Alphabet> {
  const AlphabetDecoder();

  @override
  Alphabet convert(Map map) => AlphabetSerializer.fromMap(map);
}

class AlphabetSerializer extends Codec<Alphabet, Map> {
  const AlphabetSerializer();

  @override
  AlphabetEncoder get encoder => const AlphabetEncoder();

  @override
  AlphabetDecoder get decoder => const AlphabetDecoder();

  static Alphabet fromMap(Map map) {
    return Alphabet(
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
      value: map['value'] as String?,
      numbers: map['numbers'] != null
          ? NumberSerializer.fromMap(map['numbers'] as Map)
          : null,
    );
  }

  static Map<String, dynamic> toMap(AlphabetEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'value': model.value,
      'numbers': NumberSerializer.toMap(model.numbers),
    };
  }
}

abstract class AlphabetFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    value,
    numbers,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String value = 'value';

  static const String numbers = 'numbers';
}
