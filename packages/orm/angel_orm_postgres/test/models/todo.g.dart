// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// OrmGenerator
// **************************************************************************

class UserQuery extends Query<User, UserQueryWhere> {
  UserQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserQueryWhere(this);
    leftJoin(
      _todos = UserTodoQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'user_acc_id',
      additionalFields: const [
        'id',
        'user_id',
        'title',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final UserQueryValues values = UserQueryValues();

  List<String> _selectedFields = [];

  UserQueryWhere? _where;

  late UserTodoQuery _todos;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'user_acc';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'name',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  UserQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UserQueryWhere? get where {
    return _where;
  }

  @override
  UserQueryWhere newWhereClause() {
    return UserQueryWhere(this);
  }

  Optional<User> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = User(
      id: fields.contains('id') ? mapToInt(row[0]) : 0,
      name: fields.contains('name') ? (row[1] as String) : '',
    );
    if (row.length > 2) {
      var modelOpt = UserTodoQuery().parseRow(row.skip(2).take(3).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(todos: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<User> deserialize(List row) {
    return parseRow(row);
  }

  UserTodoQuery get todos {
    return _todos;
  }

  @override
  Future<List<User>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<User>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                todos: List<_UserTodo>.from(l.todos)..addAll(model.todos));
        }
      });
    });
  }

  @override
  Future<List<User>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<User>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                todos: List<_UserTodo>.from(l.todos)..addAll(model.todos));
        }
      });
    });
  }

  @override
  Future<List<User>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<User>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                todos: List<_UserTodo>.from(l.todos)..addAll(model.todos));
        }
      });
    });
  }
}

class UserQueryWhere extends QueryWhere {
  UserQueryWhere(UserQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        name = StringSqlExpressionBuilder(
          query,
          'name',
        );

  final NumericSqlExpressionBuilder<int> id;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      name,
    ];
  }
}

class UserQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int get id {
    return (values['id'] as int);
  }

  set id(int value) => values['id'] = value;

  String get name {
    return (values['name'] as String);
  }

  set name(String value) => values['name'] = value;

  void copyFrom(User model) {
    id = model.id;
    name = model.name;
  }
}

class UserTodoQuery extends Query<UserTodo, UserTodoQueryWhere> {
  UserTodoQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserTodoQueryWhere(this);
    leftJoin(
      _todoValues = TodoValueQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'todo_id',
      additionalFields: const [
        'id',
        'value',
        'todo_id',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final UserTodoQueryValues values = UserTodoQueryValues();

  List<String> _selectedFields = [];

  UserTodoQueryWhere? _where;

  late TodoValueQuery _todoValues;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'user_todo';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'user_id',
      'title',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  UserTodoQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UserTodoQueryWhere? get where {
    return _where;
  }

  @override
  UserTodoQueryWhere newWhereClause() {
    return UserTodoQueryWhere(this);
  }

  Optional<UserTodo> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UserTodo(
      id: fields.contains('id') ? mapToInt(row[0]) : 0,
      userId: fields.contains('user_id') ? mapToInt(row[1]) : 0,
      title: fields.contains('title') ? (row[2] as String) : '',
    );
    if (row.length > 3) {
      var modelOpt = TodoValueQuery().parseRow(row.skip(3).take(3).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(todoValues: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<UserTodo> deserialize(List row) {
    return parseRow(row);
  }

  TodoValueQuery get todoValues {
    return _todoValues;
  }

  @override
  Future<List<UserTodo>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<UserTodo>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                todoValues: List<_TodoValue>.from(l.todoValues)
                  ..addAll(model.todoValues));
        }
      });
    });
  }

  @override
  Future<List<UserTodo>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<UserTodo>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                todoValues: List<_TodoValue>.from(l.todoValues)
                  ..addAll(model.todoValues));
        }
      });
    });
  }

  @override
  Future<List<UserTodo>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<UserTodo>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                todoValues: List<_TodoValue>.from(l.todoValues)
                  ..addAll(model.todoValues));
        }
      });
    });
  }
}

class UserTodoQueryWhere extends QueryWhere {
  UserTodoQueryWhere(UserTodoQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        userId = NumericSqlExpressionBuilder<int>(
          query,
          'user_id',
        ),
        title = StringSqlExpressionBuilder(
          query,
          'title',
        );

  final NumericSqlExpressionBuilder<int> id;

  final NumericSqlExpressionBuilder<int> userId;

  final StringSqlExpressionBuilder title;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      userId,
      title,
    ];
  }
}

class UserTodoQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int get id {
    return (values['id'] as int);
  }

  set id(int value) => values['id'] = value;

  int get userId {
    return (values['user_id'] as int);
  }

  set userId(int value) => values['user_id'] = value;

  String get title {
    return (values['title'] as String);
  }

  set title(String value) => values['title'] = value;

  void copyFrom(UserTodo model) {
    id = model.id;
    userId = model.userId;
    title = model.title;
  }
}

class TodoValueQuery extends Query<TodoValue, TodoValueQueryWhere> {
  TodoValueQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = TodoValueQueryWhere(this);
  }

  @override
  final TodoValueQueryValues values = TodoValueQueryValues();

  List<String> _selectedFields = [];

  TodoValueQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'todo_value';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'value',
      'todo_id',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  TodoValueQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  TodoValueQueryWhere? get where {
    return _where;
  }

  @override
  TodoValueQueryWhere newWhereClause() {
    return TodoValueQueryWhere(this);
  }

  Optional<TodoValue> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = TodoValue(
      id: fields.contains('id') ? mapToInt(row[0]) : 0,
      value: fields.contains('value') ? (row[1] as String) : '',
      todoId: fields.contains('todo_id') ? mapToInt(row[2]) : 0,
    );
    return Optional.of(model);
  }

  @override
  Optional<TodoValue> deserialize(List row) {
    return parseRow(row);
  }
}

class TodoValueQueryWhere extends QueryWhere {
  TodoValueQueryWhere(TodoValueQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        value = StringSqlExpressionBuilder(
          query,
          'value',
        ),
        todoId = NumericSqlExpressionBuilder<int>(
          query,
          'todo_id',
        );

  final NumericSqlExpressionBuilder<int> id;

  final StringSqlExpressionBuilder value;

  final NumericSqlExpressionBuilder<int> todoId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      value,
      todoId,
    ];
  }
}

class TodoValueQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int get id {
    return (values['id'] as int);
  }

  set id(int value) => values['id'] = value;

  String get value {
    return (values['value'] as String);
  }

  set value(String value) => values['value'] = value;

  int get todoId {
    return (values['todo_id'] as int);
  }

  set todoId(int value) => values['todo_id'] = value;

  void copyFrom(TodoValue model) {
    id = model.id;
    value = model.value;
    todoId = model.todoId;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class User implements _User {
  User({
    required this.id,
    required this.name,
    this.todos = const [],
  });

  @override
  int id;

  @override
  String name;

  @override
  List<_UserTodo> todos;

  User copyWith({
    int? id,
    String? name,
    List<_UserTodo>? todos,
  }) {
    return User(
        id: id ?? this.id, name: name ?? this.name, todos: todos ?? this.todos);
  }

  @override
  bool operator ==(other) {
    return other is _User &&
        other.id == id &&
        other.name == name &&
        ListEquality<_UserTodo>(DefaultEquality<_UserTodo>())
            .equals(other.todos, todos);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      name,
      todos,
    ]);
  }

  @override
  String toString() {
    return 'User(id=$id, name=$name, todos=$todos)';
  }

  Map<String, dynamic> toJson() {
    return UserSerializer.toMap(this);
  }
}

@generatedSerializable
class UserTodo implements _UserTodo {
  UserTodo({
    required this.id,
    required this.userId,
    required this.title,
    this.todoValues = const [],
  });

  @override
  int id;

  @override
  int userId;

  @override
  String title;

  @override
  List<_TodoValue> todoValues;

  UserTodo copyWith({
    int? id,
    int? userId,
    String? title,
    List<_TodoValue>? todoValues,
  }) {
    return UserTodo(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        todoValues: todoValues ?? this.todoValues);
  }

  @override
  bool operator ==(other) {
    return other is _UserTodo &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        ListEquality<_TodoValue>(DefaultEquality<_TodoValue>())
            .equals(other.todoValues, todoValues);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      userId,
      title,
      todoValues,
    ]);
  }

  @override
  String toString() {
    return 'UserTodo(id=$id, userId=$userId, title=$title, todoValues=$todoValues)';
  }

  Map<String, dynamic> toJson() {
    return UserTodoSerializer.toMap(this);
  }
}

@generatedSerializable
class TodoValue implements _TodoValue {
  TodoValue({
    required this.id,
    required this.value,
    required this.todoId,
  });

  @override
  int id;

  @override
  String value;

  @override
  int todoId;

  TodoValue copyWith({
    int? id,
    String? value,
    int? todoId,
  }) {
    return TodoValue(
        id: id ?? this.id,
        value: value ?? this.value,
        todoId: todoId ?? this.todoId);
  }

  @override
  bool operator ==(other) {
    return other is _TodoValue &&
        other.id == id &&
        other.value == value &&
        other.todoId == todoId;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      value,
      todoId,
    ]);
  }

  @override
  String toString() {
    return 'TodoValue(id=$id, value=$value, todoId=$todoId)';
  }

  Map<String, dynamic> toJson() {
    return TodoValueSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const UserSerializer userSerializer = UserSerializer();

class UserEncoder extends Converter<User, Map> {
  const UserEncoder();

  @override
  Map convert(User model) => UserSerializer.toMap(model);
}

class UserDecoder extends Converter<Map, User> {
  const UserDecoder();

  @override
  User convert(Map map) => UserSerializer.fromMap(map);
}

class UserSerializer extends Codec<User, Map> {
  const UserSerializer();

  @override
  UserEncoder get encoder => const UserEncoder();

  @override
  UserDecoder get decoder => const UserDecoder();

  static User fromMap(Map map) {
    return User(
        id: map['id'] as int,
        name: map['name'] as String,
        todos: map['todos'] is Iterable
            ? List.unmodifiable(((map['todos'] as Iterable).whereType<Map>())
                .map(UserTodoSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_User? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'name': model.name,
      'todos': model.todos.map((m) => UserTodoSerializer.toMap(m)).toList()
    };
  }
}

abstract class UserFields {
  static const List<String> allFields = <String>[
    id,
    name,
    todos,
  ];

  static const String id = 'id';

  static const String name = 'name';

  static const String todos = 'todos';
}

const UserTodoSerializer userTodoSerializer = UserTodoSerializer();

class UserTodoEncoder extends Converter<UserTodo, Map> {
  const UserTodoEncoder();

  @override
  Map convert(UserTodo model) => UserTodoSerializer.toMap(model);
}

class UserTodoDecoder extends Converter<Map, UserTodo> {
  const UserTodoDecoder();

  @override
  UserTodo convert(Map map) => UserTodoSerializer.fromMap(map);
}

class UserTodoSerializer extends Codec<UserTodo, Map> {
  const UserTodoSerializer();

  @override
  UserTodoEncoder get encoder => const UserTodoEncoder();

  @override
  UserTodoDecoder get decoder => const UserTodoDecoder();

  static UserTodo fromMap(Map map) {
    return UserTodo(
        id: map['id'] as int,
        userId: map['user_id'] as int,
        title: map['title'] as String,
        todoValues: map['todo_values'] is Iterable
            ? List.unmodifiable(
                ((map['todo_values'] as Iterable).whereType<Map>())
                    .map(TodoValueSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_UserTodo? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'user_id': model.userId,
      'title': model.title,
      'todo_values':
          model.todoValues.map((m) => TodoValueSerializer.toMap(m)).toList()
    };
  }
}

abstract class UserTodoFields {
  static const List<String> allFields = <String>[
    id,
    userId,
    title,
    todoValues,
  ];

  static const String id = 'id';

  static const String userId = 'user_id';

  static const String title = 'title';

  static const String todoValues = 'todo_values';
}

const TodoValueSerializer todoValueSerializer = TodoValueSerializer();

class TodoValueEncoder extends Converter<TodoValue, Map> {
  const TodoValueEncoder();

  @override
  Map convert(TodoValue model) => TodoValueSerializer.toMap(model);
}

class TodoValueDecoder extends Converter<Map, TodoValue> {
  const TodoValueDecoder();

  @override
  TodoValue convert(Map map) => TodoValueSerializer.fromMap(map);
}

class TodoValueSerializer extends Codec<TodoValue, Map> {
  const TodoValueSerializer();

  @override
  TodoValueEncoder get encoder => const TodoValueEncoder();

  @override
  TodoValueDecoder get decoder => const TodoValueDecoder();

  static TodoValue fromMap(Map map) {
    return TodoValue(
        id: map['id'] as int,
        value: map['value'] as String,
        todoId: map['todo_id'] as int);
  }

  static Map<String, dynamic> toMap(_TodoValue? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'id': model.id, 'value': model.value, 'todo_id': model.todoId};
  }
}

abstract class TodoValueFields {
  static const List<String> allFields = <String>[
    id,
    value,
    todoId,
  ];

  static const String id = 'id';

  static const String value = 'value';

  static const String todoId = 'todo_id';
}
