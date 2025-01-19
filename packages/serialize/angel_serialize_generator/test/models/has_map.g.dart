// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'has_map.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class HasMap implements _HasMap {
  HasMap({required this.value});

  @override
  Map<dynamic, dynamic>? value;

  HasMap copyWith({Map<dynamic, dynamic>? value}) {
    return HasMap(value: value ?? this.value);
  }

  @override
  bool operator ==(other) {
    return other is _HasMap &&
        MapEquality<dynamic, dynamic>(
                keys: DefaultEquality(), values: DefaultEquality())
            .equals(other.value, value);
  }

  @override
  int get hashCode {
    return hashObjects([value]);
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

  static Map<String, dynamic> toMap(_HasMap? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'value': _toString(model.value)};
  }
}

abstract class HasMapFields {
  static const List<String> allFields = <String>[value];

  static const String value = 'value';
}
