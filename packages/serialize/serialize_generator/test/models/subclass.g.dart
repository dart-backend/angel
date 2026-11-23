// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subclass.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Animal extends AnimalEntity {
  Animal({required this.genus, required this.species});

  @override
  String? genus;

  @override
  String? species;

  Animal copyWith({String? genus, String? species}) {
    return Animal(genus: genus ?? this.genus, species: species ?? this.species);
  }

  @override
  bool operator ==(other) {
    return other is AnimalEntity &&
        other.genus == genus &&
        other.species == species;
  }

  @override
  int get hashCode {
    return Object.hashAll([genus, species]);
  }

  @override
  String toString() {
    return 'Animal(genus=$genus, species=$species)';
  }

  Map<String, dynamic> toJson() {
    return AnimalSerializer.toMap(this);
  }
}

@generatedSerializable
class Bird extends BirdEntity {
  Bird({required this.genus, required this.species, this.isSparrow = false});

  @override
  String? genus;

  @override
  String? species;

  @override
  bool? isSparrow;

  Bird copyWith({String? genus, String? species, bool? isSparrow}) {
    return Bird(
      genus: genus ?? this.genus,
      species: species ?? this.species,
      isSparrow: isSparrow ?? this.isSparrow,
    );
  }

  @override
  bool operator ==(other) {
    return other is BirdEntity &&
        other.genus == genus &&
        other.species == species &&
        other.isSparrow == isSparrow;
  }

  @override
  int get hashCode {
    return Object.hashAll([genus, species, isSparrow]);
  }

  @override
  String toString() {
    return 'Bird(genus=$genus, species=$species, isSparrow=$isSparrow)';
  }

  Map<String, dynamic> toJson() {
    return BirdSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const AnimalSerializer animalSerializer = AnimalSerializer();

class AnimalEncoder extends Converter<Animal, Map> {
  const AnimalEncoder();

  @override
  Map convert(Animal model) => AnimalSerializer.toMap(model);
}

class AnimalDecoder extends Converter<Map, Animal> {
  const AnimalDecoder();

  @override
  Animal convert(Map map) => AnimalSerializer.fromMap(map);
}

class AnimalSerializer extends Codec<Animal, Map> {
  const AnimalSerializer();

  /// The name of the JSON Schema of [Animal].
  static const String schemaName = 'Animal';

  /// The JSON Schema of the map that [toMap] writes of [Animal], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'genus': {'type': 'string'},
      'species': {'type': 'string'},
    },
    'required': ['genus', 'species'],
  };

  @override
  AnimalEncoder get encoder => const AnimalEncoder();

  @override
  AnimalDecoder get decoder => const AnimalDecoder();

  static Animal fromMap(Map map) {
    if (map['genus'] == null) {
      throw FormatException("Missing required field 'genus' on Animal.");
    }

    if (map['species'] == null) {
      throw FormatException("Missing required field 'species' on Animal.");
    }

    return Animal(
      genus: map['genus'] as String?,
      species: map['species'] as String?,
    );
  }

  /// Adds the JSON Schema of [Animal], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(AnimalEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    if (model.genus == null) {
      throw FormatException("Missing required field 'genus' on Animal.");
    }

    if (model.species == null) {
      throw FormatException("Missing required field 'species' on Animal.");
    }

    return {'genus': model.genus, 'species': model.species};
  }
}

abstract class AnimalFields {
  static const List<String> allFields = <String>[genus, species];

  static const String genus = 'genus';

  static const String species = 'species';
}

const BirdSerializer birdSerializer = BirdSerializer();

class BirdEncoder extends Converter<Bird, Map> {
  const BirdEncoder();

  @override
  Map convert(Bird model) => BirdSerializer.toMap(model);
}

class BirdDecoder extends Converter<Map, Bird> {
  const BirdDecoder();

  @override
  Bird convert(Map map) => BirdSerializer.fromMap(map);
}

class BirdSerializer extends Codec<Bird, Map> {
  const BirdSerializer();

  /// The name of the JSON Schema of [Bird].
  static const String schemaName = 'Bird';

  /// The JSON Schema of the map that [toMap] writes of [Bird], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'genus': {'type': 'string'},
      'species': {'type': 'string'},
      'is_sparrow': {
        'type': ['boolean', 'null'],
      },
    },
    'required': ['genus', 'species'],
  };

  @override
  BirdEncoder get encoder => const BirdEncoder();

  @override
  BirdDecoder get decoder => const BirdDecoder();

  static Bird fromMap(Map map) {
    if (map['genus'] == null) {
      throw FormatException("Missing required field 'genus' on Bird.");
    }

    if (map['species'] == null) {
      throw FormatException("Missing required field 'species' on Bird.");
    }

    return Bird(
      genus: map['genus'] as String?,
      species: map['species'] as String?,
      isSparrow: map['is_sparrow'] as bool? ?? false,
    );
  }

  /// Adds the JSON Schema of [Bird], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(BirdEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    if (model.genus == null) {
      throw FormatException("Missing required field 'genus' on Bird.");
    }

    if (model.species == null) {
      throw FormatException("Missing required field 'species' on Bird.");
    }

    return {
      'genus': model.genus,
      'species': model.species,
      'is_sparrow': model.isSparrow,
    };
  }
}

abstract class BirdFields {
  static const List<String> allFields = <String>[genus, species, isSparrow];

  static const String genus = 'genus';

  static const String species = 'species';

  static const String isSparrow = 'is_sparrow';
}
