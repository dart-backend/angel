// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class TodoMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('todos', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('text', length: 255);
      table.boolean('is_complete').defaultsTo(false);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('todos');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class TodoQuery extends Query<Todo, TodoQueryWhere> {
  TodoQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = TodoQueryWhere(this);
  }

  @override
  final TodoQueryValues values = TodoQueryValues();

  List<String> _selectedFields = [];

  TodoQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'todos';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'text',
      'is_complete',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  TodoQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  TodoQueryWhere? get where {
    return _where;
  }

  @override
  TodoQueryWhere newWhereClause() {
    return TodoQueryWhere(this);
  }

  Optional<Todo> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Todo(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[1])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[2])
          : null,
      text: fields.contains('text') ? (row[3] as String?) : null,
      isComplete: fields.contains('is_complete') ? mapToBool(row[4]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Todo> deserialize(List row) {
    return parseRow(row);
  }
}

class TodoQueryWhere extends QueryWhere {
  TodoQueryWhere(TodoQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      text = StringSqlExpressionBuilder(query, 'text'),
      isComplete = BooleanSqlExpressionBuilder(query, 'is_complete');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder text;

  final BooleanSqlExpressionBuilder isComplete;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, text, isComplete];
  }
}

class TodoQueryValues extends MapQueryValues {
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

  String? get text {
    return (values['text'] as String?);
  }

  set text(String? value) => values['text'] = value;

  bool? get isComplete {
    return (values['is_complete'] as bool?);
  }

  set isComplete(bool? value) => values['is_complete'] = value;

  void copyFrom(Todo model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    text = model.text;
    isComplete = model.isComplete;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Todo extends TodoEntity {
  Todo({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.text,
    this.isComplete = false,
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
  String? text;

  @override
  bool? isComplete;

  Todo copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? text,
    bool? isComplete,
  }) {
    return Todo(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      text: text ?? this.text,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  bool operator ==(other) {
    return other is TodoEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.text == text &&
        other.isComplete == isComplete;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, text, isComplete]);
  }

  @override
  String toString() {
    return 'Todo(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, text=$text, isComplete=$isComplete)';
  }

  Map<String, dynamic> toJson() {
    return TodoSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const TodoSerializer todoSerializer = TodoSerializer();

class TodoEncoder extends Converter<Todo, Map> {
  const TodoEncoder();

  @override
  Map convert(Todo model) => TodoSerializer.toMap(model);
}

class TodoDecoder extends Converter<Map, Todo> {
  const TodoDecoder();

  @override
  Todo convert(Map map) => TodoSerializer.fromMap(map);
}

class TodoSerializer extends Codec<Todo, Map> {
  const TodoSerializer();

  @override
  TodoEncoder get encoder => const TodoEncoder();

  @override
  TodoDecoder get decoder => const TodoDecoder();

  static Todo fromMap(Map map) {
    return Todo(
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
      text: map['text'] as String?,
      isComplete: map['is_complete'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toMap(TodoEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'text': model.text,
      'is_complete': model.isComplete,
    };
  }
}

abstract class TodoFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    text,
    isComplete,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String text = 'text';

  static const String isComplete = 'is_complete';
}
