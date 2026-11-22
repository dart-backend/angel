// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'has_map.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class HasMap implements HasMapEntity {
  HasMap({required this.value});

  @override
  Map<dynamic, dynamic>? value;

  HasMap copyWith({Map<dynamic, dynamic>? value}) {
    return HasMap(value: value ?? this.value);
  }

  @override
  bool operator ==(other) {
    return other is HasMapEntity &&
        MapEquality<dynamic, dynamic>(
          keys: DefaultEquality(),
          values: DefaultEquality(),
        ).equals(other.value, value);
  }

  @override
  int get hashCode {
    return Object.hashAll([value?.length]);
  }

  @override
  String toString() {
    return 'HasMap(value=$value)';
  }

  Map<String, dynamic> toJson() {
    return HasMapSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const HasMapSerializer hasMapSerializer = HasMapSerializer();

class HasMapEncoder extends Converter<HasMap, Map> {
  const HasMapEncoder();

  @override
  Map convert(HasMap model) => HasMapSerializer.toMap(model);
}

class HasMapDecoder extends Converter<Map, HasMap> {
  const HasMapDecoder();

  @override
  HasMap convert(Map map) => HasMapSerializer.fromMap(map);
}

class HasMapSerializer extends Codec<HasMap, Map> {
  const HasMapSerializer();

  /// The name of the JSON Schema of [HasMap].
  static const String schemaName = 'HasMap';

  /// The JSON Schema of the map that [toMap] writes of [HasMap], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'value': {'type': 'string'},
    },
  };

  @override
  HasMapEncoder get encoder => const HasMapEncoder();

  @override
  HasMapDecoder get decoder => const HasMapDecoder();

  static HasMap fromMap(Map map) {
    if (map['value'] == null) {
      throw FormatException("Missing required field 'value' on HasMap.");
    }

    return HasMap(value: _fromString(map['value']));
  }

  /// Adds the JSON Schema of [HasMap], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(HasMapEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    if (model.value == null) {
      throw FormatException("Missing required field 'value' on HasMap.");
    }

    return {'value': _toString(model.value)};
  }
}

abstract class HasMapFields {
  static const List<String> allFields = <String>[value];

  static const String value = 'value';
}
