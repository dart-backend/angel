// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('user_acc', (table) {
      table.integer('id').primaryKey();
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('user_acc', cascade: true);
  }
}

class UserAddressMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('user_addr', (table) {
      table.integer('id')
        ..primaryKey()
        ..notNull();
      table.integer('user_id').notNull();
      table.varChar('address', length: 255).notNull();
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('user_addr');
  }
}

class UserTodoMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('user_todo', (table) {
      table.integer('id')
        ..primaryKey()
        ..notNull();
      table.integer('user_id').notNull();
      table.varChar('title', length: 255).notNull();
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('user_todo', cascade: true);
  }
}

class TodoValueMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('todo_value', (table) {
      table.integer('id').primaryKey();
      table.varChar('value', length: 255);
      table.integer('todo_id');
      table.varChar('description', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('todo_value');
  }
}

class TodoNoteMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('todo_note', (table) {
      table.integer('id').primaryKey();
      table.varChar('note', length: 255);
      table.integer('todo_id');
      table.varChar('description', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('todo_note');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class UserQuery extends Query<User, UserQueryWhere> {
  UserQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserQueryWhere(this);
    leftJoin(
      _todos = UserTodoQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'user_id',
      additionalFields: const [
        'id',
        'user_id',
        'title',
      ],
      trampoline: trampoline,
    );
    leftJoin(
      _address = UserAddressQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'user_id',
      additionalFields: const [
        'id',
        'user_id',
        'address',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final UserQueryValues values = UserQueryValues();

  List<String> _selectedFields = [];

  UserQueryWhere? _where;

  late UserTodoQuery _todos;

  late UserAddressQuery _address;

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
    const localFields = [
      'id',
      'name',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
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
    if (row.length > 5) {
      var modelOpt = UserAddressQuery().parseRow(row.skip(5).take(3).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(address: [m]);
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

  UserAddressQuery get address {
    return _address;
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
                todos: List<UserTodoEntity>.from(l.todos)..addAll(model.todos),
                address: List<UserAddressEntity>.from(l.address)
                  ..addAll(model.address));
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
                todos: List<UserTodoEntity>.from(l.todos)..addAll(model.todos),
                address: List<UserAddressEntity>.from(l.address)
                  ..addAll(model.address));
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
                todos: List<UserTodoEntity>.from(l.todos)..addAll(model.todos),
                address: List<UserAddressEntity>.from(l.address)
                  ..addAll(model.address));
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

class UserAddressQuery extends Query<UserAddress, UserAddressQueryWhere> {
  UserAddressQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserAddressQueryWhere(this);
  }

  @override
  final UserAddressQueryValues values = UserAddressQueryValues();

  List<String> _selectedFields = [];

  UserAddressQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'user_addr';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'user_id',
      'address',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  UserAddressQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UserAddressQueryWhere? get where {
    return _where;
  }

  @override
  UserAddressQueryWhere newWhereClause() {
    return UserAddressQueryWhere(this);
  }

  Optional<UserAddress> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UserAddress(
      id: fields.contains('id') ? mapToInt(row[0]) : 0,
      userId: fields.contains('user_id') ? mapToInt(row[1]) : 0,
      address: fields.contains('address') ? (row[2] as String) : '',
    );
    return Optional.of(model);
  }

  @override
  Optional<UserAddress> deserialize(List row) {
    return parseRow(row);
  }
}

class UserAddressQueryWhere extends QueryWhere {
  UserAddressQueryWhere(UserAddressQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        userId = NumericSqlExpressionBuilder<int>(
          query,
          'user_id',
        ),
        address = StringSqlExpressionBuilder(
          query,
          'address',
        );

  final NumericSqlExpressionBuilder<int> id;

  final NumericSqlExpressionBuilder<int> userId;

  final StringSqlExpressionBuilder address;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      userId,
      address,
    ];
  }
}

class UserAddressQueryValues extends MapQueryValues {
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

  String get address {
    return (values['address'] as String);
  }

  set address(String value) => values['address'] = value;

  void copyFrom(UserAddress model) {
    id = model.id;
    userId = model.userId;
    address = model.address;
  }
}

class UserTodoQuery extends Query<UserTodo, UserTodoQueryWhere> {
  UserTodoQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserTodoQueryWhere(this);
    leftJoin(
      _todoValues = TodoValueQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'todo_value_id',
      additionalFields: const [
        'id',
        'value',
        'todo_id',
        'description',
      ],
      trampoline: trampoline,
    );
    leftJoin(
      _todoNotes = TodoNoteQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'id',
      'todo_note_id',
      additionalFields: const [
        'id',
        'note',
        'todo_id',
        'description',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final UserTodoQueryValues values = UserTodoQueryValues();

  List<String> _selectedFields = [];

  UserTodoQueryWhere? _where;

  late TodoValueQuery _todoValues;

  late TodoNoteQuery _todoNotes;

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
    const localFields = [
      'id',
      'user_id',
      'title',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
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
      var modelOpt = TodoValueQuery().parseRow(row.skip(3).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(todoValues: [m]);
      });
    }
    if (row.length > 7) {
      var modelOpt = TodoNoteQuery().parseRow(row.skip(7).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(todoNotes: [m]);
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

  TodoNoteQuery get todoNotes {
    return _todoNotes;
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
                todoValues: List<TodoValueEntity>.from(l.todoValues)
                  ..addAll(model.todoValues),
                todoNotes: List<TodoNoteEntity>.from(l.todoNotes)
                  ..addAll(model.todoNotes));
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
                todoValues: List<TodoValueEntity>.from(l.todoValues)
                  ..addAll(model.todoValues),
                todoNotes: List<TodoNoteEntity>.from(l.todoNotes)
                  ..addAll(model.todoNotes));
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
                todoValues: List<TodoValueEntity>.from(l.todoValues)
                  ..addAll(model.todoValues),
                todoNotes: List<TodoNoteEntity>.from(l.todoNotes)
                  ..addAll(model.todoNotes));
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
    super.parent,
    Set<String>? trampoline,
  }) {
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
    const localFields = [
      'id',
      'value',
      'todo_id',
      'description',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
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
      description: fields.contains('description') ? (row[3] as String?) : null,
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
        ),
        description = StringSqlExpressionBuilder(
          query,
          'description',
        );

  final NumericSqlExpressionBuilder<int> id;

  final StringSqlExpressionBuilder value;

  final NumericSqlExpressionBuilder<int> todoId;

  final StringSqlExpressionBuilder description;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      value,
      todoId,
      description,
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

  String? get description {
    return (values['description'] as String?);
  }

  set description(String? value) => values['description'] = value;

  void copyFrom(TodoValue model) {
    id = model.id;
    value = model.value;
    todoId = model.todoId;
    description = model.description;
  }
}

class TodoNoteQuery extends Query<TodoNote, TodoNoteQueryWhere> {
  TodoNoteQuery({
    super.parent,
    Set<String>? trampoline,
  }) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = TodoNoteQueryWhere(this);
  }

  @override
  final TodoNoteQueryValues values = TodoNoteQueryValues();

  List<String> _selectedFields = [];

  TodoNoteQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'todo_note';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'note',
      'todo_id',
      'description',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
            .where((field) => _selectedFields.contains(field))
            .toList();
  }

  TodoNoteQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  TodoNoteQueryWhere? get where {
    return _where;
  }

  @override
  TodoNoteQueryWhere newWhereClause() {
    return TodoNoteQueryWhere(this);
  }

  Optional<TodoNote> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = TodoNote(
      id: fields.contains('id') ? mapToInt(row[0]) : 0,
      note: fields.contains('note') ? (row[1] as String) : '',
      todoId: fields.contains('todo_id') ? mapToInt(row[2]) : 0,
      description: fields.contains('description') ? (row[3] as String?) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<TodoNote> deserialize(List row) {
    return parseRow(row);
  }
}

class TodoNoteQueryWhere extends QueryWhere {
  TodoNoteQueryWhere(TodoNoteQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        note = StringSqlExpressionBuilder(
          query,
          'note',
        ),
        todoId = NumericSqlExpressionBuilder<int>(
          query,
          'todo_id',
        ),
        description = StringSqlExpressionBuilder(
          query,
          'description',
        );

  final NumericSqlExpressionBuilder<int> id;

  final StringSqlExpressionBuilder note;

  final NumericSqlExpressionBuilder<int> todoId;

  final StringSqlExpressionBuilder description;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      note,
      todoId,
      description,
    ];
  }
}

class TodoNoteQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int get id {
    return (values['id'] as int);
  }

  set id(int value) => values['id'] = value;

  String get note {
    return (values['note'] as String);
  }

  set note(String value) => values['note'] = value;

  int get todoId {
    return (values['todo_id'] as int);
  }

  set todoId(int value) => values['todo_id'] = value;

  String? get description {
    return (values['description'] as String?);
  }

  set description(String? value) => values['description'] = value;

  void copyFrom(TodoNote model) {
    id = model.id;
    note = model.note;
    todoId = model.todoId;
    description = model.description;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class User implements UserEntity {
  User({
    required this.id,
    required this.name,
    this.todos = const [],
    this.address = const [],
  });

  @override
  int id;

  @override
  String name;

  @override
  List<UserTodoEntity> todos;

  @override
  List<UserAddressEntity> address;

  User copyWith({
    int? id,
    String? name,
    List<UserTodoEntity>? todos,
    List<UserAddressEntity>? address,
  }) {
    return User(
        id: id ?? this.id,
        name: name ?? this.name,
        todos: todos ?? this.todos,
        address: address ?? this.address);
  }

  @override
  bool operator ==(other) {
    return other is UserEntity &&
        other.id == id &&
        other.name == name &&
        ListEquality<UserTodoEntity>(DefaultEquality<UserTodoEntity>())
            .equals(other.todos, todos) &&
        ListEquality<UserAddressEntity>(DefaultEquality<UserAddressEntity>())
            .equals(other.address, address);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      name,
      todos,
      address,
    ]);
  }

  @override
  String toString() {
    return 'User(id=$id, name=$name, todos=$todos, address=$address)';
  }

  Map<String, dynamic> toJson() {
    return UserSerializer.toMap(this);
  }
}

@generatedSerializable
class UserAddress implements UserAddressEntity {
  UserAddress({
    required this.id,
    required this.userId,
    required this.address,
  });

  @override
  int id;

  @override
  int userId;

  @override
  String address;

  UserAddress copyWith({
    int? id,
    int? userId,
    String? address,
  }) {
    return UserAddress(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        address: address ?? this.address);
  }

  @override
  bool operator ==(other) {
    return other is UserAddressEntity &&
        other.id == id &&
        other.userId == userId &&
        other.address == address;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      userId,
      address,
    ]);
  }

  @override
  String toString() {
    return 'UserAddress(id=$id, userId=$userId, address=$address)';
  }

  Map<String, dynamic> toJson() {
    return UserAddressSerializer.toMap(this);
  }
}

@generatedSerializable
class UserTodo implements UserTodoEntity {
  UserTodo({
    required this.id,
    required this.userId,
    required this.title,
    this.todoValues = const [],
    this.todoNotes = const [],
  });

  @override
  int id;

  @override
  int userId;

  @override
  String title;

  @override
  List<TodoValueEntity> todoValues;

  @override
  List<TodoNoteEntity> todoNotes;

  UserTodo copyWith({
    int? id,
    int? userId,
    String? title,
    List<TodoValueEntity>? todoValues,
    List<TodoNoteEntity>? todoNotes,
  }) {
    return UserTodo(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        todoValues: todoValues ?? this.todoValues,
        todoNotes: todoNotes ?? this.todoNotes);
  }

  @override
  bool operator ==(other) {
    return other is UserTodoEntity &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        ListEquality<TodoValueEntity>(DefaultEquality<TodoValueEntity>())
            .equals(other.todoValues, todoValues) &&
        ListEquality<TodoNoteEntity>(DefaultEquality<TodoNoteEntity>())
            .equals(other.todoNotes, todoNotes);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      userId,
      title,
      todoValues,
      todoNotes,
    ]);
  }

  @override
  String toString() {
    return 'UserTodo(id=$id, userId=$userId, title=$title, todoValues=$todoValues, todoNotes=$todoNotes)';
  }

  Map<String, dynamic> toJson() {
    return UserTodoSerializer.toMap(this);
  }
}

@generatedSerializable
class TodoValue implements TodoValueEntity {
  TodoValue({
    required this.id,
    required this.value,
    required this.todoId,
    this.description,
  });

  @override
  int id;

  @override
  String value;

  @override
  int todoId;

  @override
  String? description;

  TodoValue copyWith({
    int? id,
    String? value,
    int? todoId,
    String? description,
  }) {
    return TodoValue(
        id: id ?? this.id,
        value: value ?? this.value,
        todoId: todoId ?? this.todoId,
        description: description ?? this.description);
  }

  @override
  bool operator ==(other) {
    return other is TodoValueEntity &&
        other.id == id &&
        other.value == value &&
        other.todoId == todoId &&
        other.description == description;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      value,
      todoId,
      description,
    ]);
  }

  @override
  String toString() {
    return 'TodoValue(id=$id, value=$value, todoId=$todoId, description=$description)';
  }

  Map<String, dynamic> toJson() {
    return TodoValueSerializer.toMap(this);
  }
}

@generatedSerializable
class TodoNote implements TodoNoteEntity {
  TodoNote({
    required this.id,
    required this.note,
    required this.todoId,
    this.description,
  });

  @override
  int id;

  @override
  String note;

  @override
  int todoId;

  @override
  String? description;

  TodoNote copyWith({
    int? id,
    String? note,
    int? todoId,
    String? description,
  }) {
    return TodoNote(
        id: id ?? this.id,
        note: note ?? this.note,
        todoId: todoId ?? this.todoId,
        description: description ?? this.description);
  }

  @override
  bool operator ==(other) {
    return other is TodoNoteEntity &&
        other.id == id &&
        other.note == note &&
        other.todoId == todoId &&
        other.description == description;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      note,
      todoId,
      description,
    ]);
  }

  @override
  String toString() {
    return 'TodoNote(id=$id, note=$note, todoId=$todoId, description=$description)';
  }

  Map<String, dynamic> toJson() {
    return TodoNoteSerializer.toMap(this);
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
            : [],
        address: map['address'] is Iterable
            ? List.unmodifiable(((map['address'] as Iterable).whereType<Map>())
                .map(UserAddressSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(UserEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'name': model.name,
      'todos': model.todos.map((m) => UserTodoSerializer.toMap(m)).toList(),
      'address':
          model.address.map((m) => UserAddressSerializer.toMap(m)).toList()
    };
  }
}

abstract class UserFields {
  static const List<String> allFields = <String>[
    id,
    name,
    todos,
    address,
  ];

  static const String id = 'id';

  static const String name = 'name';

  static const String todos = 'todos';

  static const String address = 'address';
}

const UserAddressSerializer userAddressSerializer = UserAddressSerializer();

class UserAddressEncoder extends Converter<UserAddress, Map> {
  const UserAddressEncoder();

  @override
  Map convert(UserAddress model) => UserAddressSerializer.toMap(model);
}

class UserAddressDecoder extends Converter<Map, UserAddress> {
  const UserAddressDecoder();

  @override
  UserAddress convert(Map map) => UserAddressSerializer.fromMap(map);
}

class UserAddressSerializer extends Codec<UserAddress, Map> {
  const UserAddressSerializer();

  @override
  UserAddressEncoder get encoder => const UserAddressEncoder();

  @override
  UserAddressDecoder get decoder => const UserAddressDecoder();

  static UserAddress fromMap(Map map) {
    return UserAddress(
        id: map['id'] as int,
        userId: map['user_id'] as int,
        address: map['address'] as String);
  }

  static Map<String, dynamic> toMap(UserAddressEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'id': model.id, 'user_id': model.userId, 'address': model.address};
  }
}

abstract class UserAddressFields {
  static const List<String> allFields = <String>[
    id,
    userId,
    address,
  ];

  static const String id = 'id';

  static const String userId = 'user_id';

  static const String address = 'address';
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
            : [],
        todoNotes: map['todo_notes'] is Iterable
            ? List.unmodifiable(
                ((map['todo_notes'] as Iterable).whereType<Map>())
                    .map(TodoNoteSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(UserTodoEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'user_id': model.userId,
      'title': model.title,
      'todo_values':
          model.todoValues.map((m) => TodoValueSerializer.toMap(m)).toList(),
      'todo_notes':
          model.todoNotes.map((m) => TodoNoteSerializer.toMap(m)).toList()
    };
  }
}

abstract class UserTodoFields {
  static const List<String> allFields = <String>[
    id,
    userId,
    title,
    todoValues,
    todoNotes,
  ];

  static const String id = 'id';

  static const String userId = 'user_id';

  static const String title = 'title';

  static const String todoValues = 'todo_values';

  static const String todoNotes = 'todo_notes';
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
        todoId: map['todo_id'] as int,
        description: map['description'] as String?);
  }

  static Map<String, dynamic> toMap(TodoValueEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'value': model.value,
      'todo_id': model.todoId,
      'description': model.description
    };
  }
}

abstract class TodoValueFields {
  static const List<String> allFields = <String>[
    id,
    value,
    todoId,
    description,
  ];

  static const String id = 'id';

  static const String value = 'value';

  static const String todoId = 'todo_id';

  static const String description = 'description';
}

const TodoNoteSerializer todoNoteSerializer = TodoNoteSerializer();

class TodoNoteEncoder extends Converter<TodoNote, Map> {
  const TodoNoteEncoder();

  @override
  Map convert(TodoNote model) => TodoNoteSerializer.toMap(model);
}

class TodoNoteDecoder extends Converter<Map, TodoNote> {
  const TodoNoteDecoder();

  @override
  TodoNote convert(Map map) => TodoNoteSerializer.fromMap(map);
}

class TodoNoteSerializer extends Codec<TodoNote, Map> {
  const TodoNoteSerializer();

  @override
  TodoNoteEncoder get encoder => const TodoNoteEncoder();

  @override
  TodoNoteDecoder get decoder => const TodoNoteDecoder();

  static TodoNote fromMap(Map map) {
    return TodoNote(
        id: map['id'] as int,
        note: map['note'] as String,
        todoId: map['todo_id'] as int,
        description: map['description'] as String?);
  }

  static Map<String, dynamic> toMap(TodoNoteEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'note': model.note,
      'todo_id': model.todoId,
      'description': model.description
    };
  }
}

abstract class TodoNoteFields {
  static const List<String> allFields = <String>[
    id,
    note,
    todoId,
    description,
  ];

  static const String id = 'id';

  static const String note = 'note';

  static const String todoId = 'todo_id';

  static const String description = 'description';
}
