// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Todo extends TodoEntity {
  Todo({this.text, this.completed});

  @override
  String? text;

  @override
  bool? completed;

  Todo copyWith({String? text, bool? completed}) {
    return Todo(
      text: text ?? this.text,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(other) {
    return other is TodoEntity &&
        other.text == text &&
        other.completed == completed;
  }

  @override
  int get hashCode {
    return hashObjects([text, completed]);
  }

  @override
  String toString() {
    return 'Todo(text=$text, completed=$completed)';
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
      text: map['text'] as String?,
      completed: map['completed'] as bool?,
    );
  }

  static Map<String, dynamic> toMap(TodoEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'text': model.text, 'completed': model.completed};
  }
}

abstract class TodoFields {
  static const List<String> allFields = <String>[text, completed];

  static const String text = 'text';

  static const String completed = 'completed';
}
