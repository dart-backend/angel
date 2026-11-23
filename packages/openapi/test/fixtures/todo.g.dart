// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Todo implements TodoEntity {
  Todo({required this.text, this.completed, this.owner});

  @override
  String? text;

  @override
  bool? completed;

  @override
  UserEntity? owner;

  Todo copyWith({String? text, bool? completed, UserEntity? owner}) {
    return Todo(
      text: text ?? this.text,
      completed: completed ?? this.completed,
      owner: owner ?? this.owner,
    );
  }

  @override
  bool operator ==(other) {
    return other is TodoEntity &&
        other.text == text &&
        other.completed == completed &&
        other.owner == owner;
  }

  @override
  int get hashCode {
    return Object.hashAll([text, completed, owner]);
  }

  @override
  String toString() {
    return 'Todo(text=$text, completed=$completed, owner=$owner)';
  }

  Map<String, dynamic> toJson() {
    return TodoSerializer.toMap(this);
  }
}

@generatedSerializable
class User implements UserEntity {
  User({required this.name});

  @override
  String name;

  User copyWith({String? name}) {
    return User(name: name ?? this.name);
  }

  @override
  bool operator ==(other) {
    return other is UserEntity && other.name == name;
  }

  @override
  int get hashCode {
    return Object.hashAll([name]);
  }

  @override
  String toString() {
    return 'User(name=$name)';
  }

  Map<String, dynamic> toJson() {
    return UserSerializer.toMap(this);
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

  /// The name of the JSON Schema of [Todo].
  static const String schemaName = 'Todo';

  /// The JSON Schema of the map that [toMap] writes of [Todo], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'text': {'type': 'string'},
      'completed': {
        'type': ['boolean', 'null'],
      },
      'owner': {
        'anyOf': [
          {'\$ref': '#/components/schemas/User'},
          {'type': 'null'},
        ],
      },
    },
    'required': ['text'],
  };

  @override
  TodoEncoder get encoder => const TodoEncoder();

  @override
  TodoDecoder get decoder => const TodoDecoder();

  static Todo fromMap(Map map) {
    if (map['text'] == null) {
      throw FormatException("Missing required field 'text' on Todo.");
    }

    return Todo(
      text: map['text'] as String?,
      completed: map['completed'] as bool?,
      owner: map['owner'] != null
          ? UserSerializer.fromMap(map['owner'] as Map)
          : null,
    );
  }

  /// Adds the JSON Schema of [Todo], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UserSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(TodoEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    if (model.text == null) {
      throw FormatException("Missing required field 'text' on Todo.");
    }

    return {
      'text': model.text,
      'completed': model.completed,
      'owner': model.owner == null ? null : UserSerializer.toMap(model.owner),
    };
  }
}

abstract class TodoFields {
  static const List<String> allFields = <String>[text, completed, owner];

  static const String text = 'text';

  static const String completed = 'completed';

  static const String owner = 'owner';
}

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

  /// The name of the JSON Schema of [User].
  static const String schemaName = 'User';

  /// The JSON Schema of the map that [toMap] writes of [User], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  UserEncoder get encoder => const UserEncoder();

  @override
  UserDecoder get decoder => const UserDecoder();

  static User fromMap(Map map) {
    return User(name: map['name'] as String);
  }

  /// Adds the JSON Schema of [User], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(UserEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'name': model.name};
  }
}

abstract class UserFields {
  static const List<String> allFields = <String>[name];

  static const String name = 'name';
}
