// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_edge.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Edge implements EdgeEntity {
  Edge({
    this.odd,
    this.carsByName,
    this.hidden,
    this.count = 3,
    this.custom,
    required this.label,
  });

  @override
  String? odd;

  @override
  Map<String, CarEntity>? carsByName;

  @override
  String? hidden;

  @override
  int count;

  @override
  String? custom;

  @override
  String label;

  Edge copyWith({
    String? odd,
    Map<String, CarEntity>? carsByName,
    String? hidden,
    int? count,
    String? custom,
    String? label,
  }) {
    return Edge(
      odd: odd ?? this.odd,
      carsByName: carsByName ?? this.carsByName,
      hidden: hidden ?? this.hidden,
      count: count ?? this.count,
      custom: custom ?? this.custom,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(other) {
    return other is EdgeEntity &&
        other.odd == odd &&
        MapEquality<String, CarEntity>(
          keys: DefaultEquality<String>(),
          values: DefaultEquality<CarEntity>(),
        ).equals(other.carsByName, carsByName) &&
        other.hidden == hidden &&
        other.count == count &&
        other.custom == custom &&
        other.label == label;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      odd,
      carsByName?.length,
      hidden,
      count,
      custom,
      label,
    ]);
  }

  @override
  String toString() {
    return 'Edge(odd=$odd, carsByName=$carsByName, hidden=$hidden, count=$count, custom=$custom, label=$label)';
  }

  Map<String, dynamic> toJson() {
    return EdgeSerializer.toMap(this);
  }
}

@generatedSerializable
class Node implements NodeEntity {
  Node({this.name, this.children = const []});

  @override
  String? name;

  @override
  List<NodeEntity>? children;

  Node copyWith({String? name, List<NodeEntity>? children}) {
    return Node(name: name ?? this.name, children: children ?? this.children);
  }

  @override
  bool operator ==(other) {
    return other is NodeEntity &&
        other.name == name &&
        ListEquality<NodeEntity>(DefaultEquality<NodeEntity>())
            .equals(other.children, children);
  }

  @override
  int get hashCode {
    return Object.hashAll([name, children?.length]);
  }

  @override
  String toString() {
    return 'Node(name=$name, children=$children)';
  }

  Map<String, dynamic> toJson() {
    return NodeSerializer.toMap(this);
  }
}

@generatedSerializable
class Person implements PersonEntity {
  Person({this.name, this.pet});

  @override
  String? name;

  @override
  PetEntity? pet;

  Person copyWith({String? name, PetEntity? pet}) {
    return Person(name: name ?? this.name, pet: pet ?? this.pet);
  }

  @override
  bool operator ==(other) {
    return other is PersonEntity && other.name == name && other.pet == pet;
  }

  @override
  int get hashCode {
    return Object.hashAll([name, pet]);
  }

  @override
  String toString() {
    return 'Person(name=$name, pet=$pet)';
  }

  Map<String, dynamic> toJson() {
    return PersonSerializer.toMap(this);
  }
}

@generatedSerializable
class Pet implements PetEntity {
  Pet({this.name, this.owner});

  @override
  String? name;

  @override
  PersonEntity? owner;

  Pet copyWith({String? name, PersonEntity? owner}) {
    return Pet(name: name ?? this.name, owner: owner ?? this.owner);
  }

  @override
  bool operator ==(other) {
    return other is PetEntity && other.name == name && other.owner == owner;
  }

  @override
  int get hashCode {
    return Object.hashAll([name, owner]);
  }

  @override
  String toString() {
    return 'Pet(name=$name, owner=$owner)';
  }

  Map<String, dynamic> toJson() {
    return PetSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const EdgeSerializer edgeSerializer = EdgeSerializer();

class EdgeEncoder extends Converter<Edge, Map> {
  const EdgeEncoder();

  @override
  Map convert(Edge model) => EdgeSerializer.toMap(model);
}

class EdgeDecoder extends Converter<Map, Edge> {
  const EdgeDecoder();

  @override
  Edge convert(Map map) => EdgeSerializer.fromMap(map);
}

class EdgeSerializer extends Codec<Edge, Map> {
  const EdgeSerializer();

  /// The name of the JSON Schema of [Edge].
  static const String schemaName = 'Edge';

  /// The JSON Schema of the map that [toMap] writes of [Edge], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'Odd Name': {
        'type': ['string', 'null'],
      },
      'cars_by_name': {
        'type': ['object', 'null'],
        'additionalProperties': {'\$ref': '#/components/schemas/Car'},
      },
      'count': {'type': 'integer'},
      'custom': {},
      'label': {'type': 'string'},
    },
    'required': ['label'],
  };

  @override
  EdgeEncoder get encoder => const EdgeEncoder();

  @override
  EdgeDecoder get decoder => const EdgeDecoder();

  static Edge fromMap(Map map) {
    return Edge(
      odd: map['Odd Name'] as String?,
      carsByName: map['cars_by_name'] is Map
          ? Map.unmodifiable(
              (map['cars_by_name'] as Map).keys.fold({}, (out, key) {
                return out
                  ..[key] = CarSerializer.fromMap(
                    ((map['cars_by_name'] as Map)[key]) as Map,
                  );
              }),
            )
          : {},
      count: map['count'] as int? ?? 3,
      custom: _lower(map['custom']),
      label: map['label'] as String,
    );
  }

  /// Adds the JSON Schema of [Edge], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    CarSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(EdgeEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'Odd Name': model.odd,
      'cars_by_name': model.carsByName == null
          ? null
          : model.carsByName!.keys.fold({}, (map, key) {
              return map..[key] = CarSerializer.toMap(model.carsByName![key]);
            }),
      'count': model.count,
      'custom': _upper(model.custom),
      'label': model.label,
    };
  }
}

abstract class EdgeFields {
  static const List<String> allFields = <String>[
    odd,
    carsByName,
    hidden,
    count,
    custom,
    label,
  ];

  static const String odd = 'Odd Name';

  static const String carsByName = 'cars_by_name';

  static const String hidden = 'hidden';

  static const String count = 'count';

  static const String custom = 'custom';

  static const String label = 'label';
}

const NodeSerializer nodeSerializer = NodeSerializer();

class NodeEncoder extends Converter<Node, Map> {
  const NodeEncoder();

  @override
  Map convert(Node model) => NodeSerializer.toMap(model);
}

class NodeDecoder extends Converter<Map, Node> {
  const NodeDecoder();

  @override
  Node convert(Map map) => NodeSerializer.fromMap(map);
}

class NodeSerializer extends Codec<Node, Map> {
  const NodeSerializer();

  /// The name of the JSON Schema of [Node].
  static const String schemaName = 'Node';

  /// The JSON Schema of the map that [toMap] writes of [Node], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'name': {
        'type': ['string', 'null'],
      },
      'children': {
        'type': ['array', 'null'],
        'items': {'\$ref': '#/components/schemas/Node'},
      },
    },
  };

  @override
  NodeEncoder get encoder => const NodeEncoder();

  @override
  NodeDecoder get decoder => const NodeDecoder();

  static Node fromMap(Map map) {
    return Node(
      name: map['name'] as String?,
      children: map['children'] is Iterable
          ? List.unmodifiable(
              ((map['children'] as Iterable).whereType<Map>()).map(
                NodeSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  /// Adds the JSON Schema of [Node], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(NodeEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'name': model.name,
      'children': model.children?.map((m) => NodeSerializer.toMap(m)).toList(),
    };
  }
}

abstract class NodeFields {
  static const List<String> allFields = <String>[name, children];

  static const String name = 'name';

  static const String children = 'children';
}

const PersonSerializer personSerializer = PersonSerializer();

class PersonEncoder extends Converter<Person, Map> {
  const PersonEncoder();

  @override
  Map convert(Person model) => PersonSerializer.toMap(model);
}

class PersonDecoder extends Converter<Map, Person> {
  const PersonDecoder();

  @override
  Person convert(Map map) => PersonSerializer.fromMap(map);
}

class PersonSerializer extends Codec<Person, Map> {
  const PersonSerializer();

  /// The name of the JSON Schema of [Person].
  static const String schemaName = 'Person';

  /// The JSON Schema of the map that [toMap] writes of [Person], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'name': {
        'type': ['string', 'null'],
      },
      'pet': {
        'anyOf': [
          {'\$ref': '#/components/schemas/Pet'},
          {'type': 'null'},
        ],
      },
    },
  };

  @override
  PersonEncoder get encoder => const PersonEncoder();

  @override
  PersonDecoder get decoder => const PersonDecoder();

  static Person fromMap(Map map) {
    return Person(
      name: map['name'] as String?,
      pet: map['pet'] != null ? PetSerializer.fromMap(map['pet'] as Map) : null,
    );
  }

  /// Adds the JSON Schema of [Person], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    PetSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(PersonEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'name': model.name,
      'pet': model.pet == null ? null : PetSerializer.toMap(model.pet),
    };
  }
}

abstract class PersonFields {
  static const List<String> allFields = <String>[name, pet];

  static const String name = 'name';

  static const String pet = 'pet';
}

const PetSerializer petSerializer = PetSerializer();

class PetEncoder extends Converter<Pet, Map> {
  const PetEncoder();

  @override
  Map convert(Pet model) => PetSerializer.toMap(model);
}

class PetDecoder extends Converter<Map, Pet> {
  const PetDecoder();

  @override
  Pet convert(Map map) => PetSerializer.fromMap(map);
}

class PetSerializer extends Codec<Pet, Map> {
  const PetSerializer();

  /// The name of the JSON Schema of [Pet].
  static const String schemaName = 'Pet';

  /// The JSON Schema of the map that [toMap] writes of [Pet], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'name': {
        'type': ['string', 'null'],
      },
      'owner': {
        'anyOf': [
          {'\$ref': '#/components/schemas/Person'},
          {'type': 'null'},
        ],
      },
    },
  };

  @override
  PetEncoder get encoder => const PetEncoder();

  @override
  PetDecoder get decoder => const PetDecoder();

  static Pet fromMap(Map map) {
    return Pet(
      name: map['name'] as String?,
      owner: map['owner'] != null
          ? PersonSerializer.fromMap(map['owner'] as Map)
          : null,
    );
  }

  /// Adds the JSON Schema of [Pet], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    PersonSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(PetEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'name': model.name,
      'owner': model.owner == null ? null : PersonSerializer.toMap(model.owner),
    };
  }
}

abstract class PetFields {
  static const List<String> allFields = <String>[name, owner];

  static const String name = 'name';

  static const String owner = 'owner';
}
