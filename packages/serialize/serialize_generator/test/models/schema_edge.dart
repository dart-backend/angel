import 'package:angel3_serialize/angel3_serialize.dart';

import 'garage.dart';

part 'schema_edge.g.dart';

String _upper(String? v) => v?.toUpperCase() ?? '';
String? _lower(dynamic v) => (v as String?)?.toLowerCase();

/// Fields whose JSON Schema is not plain.
@serializable
abstract class EdgeEntity {
  @SerializableField(alias: 'Odd Name')
  String? get odd;

  Map<String, CarEntity>? get carsByName;

  @SerializableField(exclude: true)
  String? get hidden;

  @SerializableField(defaultValue: 3)
  int get count;

  @SerializableField(serializer: #_upper, deserializer: #_lower)
  String? get custom;

  String get label;
}

/// A model that holds others of its own class.
@serializable
abstract class NodeEntity {
  String? get name;

  List<NodeEntity>? get children;
}

/// Two models that hold each other.
@serializable
abstract class PersonEntity {
  String? get name;

  PetEntity? get pet;
}

@serializable
abstract class PetEntity {
  String? get name;

  PersonEntity? get owner;
}
