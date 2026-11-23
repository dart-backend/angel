import 'package:angel3_serialize/angel3_serialize.dart';

part 'todo.g.dart';

/// A model whose JSON Schema `angel3_serialize_generator` generates.
@serializable
abstract class TodoEntity {
  @SerializableField(isNullable: false)
  String? get text;

  bool? get completed;

  UserEntity? get owner;
}

@serializable
abstract class UserEntity {
  String get name;
}
