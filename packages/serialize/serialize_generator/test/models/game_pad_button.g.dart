// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_pad_button.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class GamepadButton implements GamepadButtonEntity {
  GamepadButton({this.name, this.radius});

  @override
  String? name;

  @override
  int? radius;

  GamepadButton copyWith({String? name, int? radius}) {
    return GamepadButton(
      name: name ?? this.name,
      radius: radius ?? this.radius,
    );
  }

  @override
  bool operator ==(other) {
    return other is GamepadButtonEntity &&
        other.name == name &&
        other.radius == radius;
  }

  @override
  int get hashCode {
    return Object.hashAll([name, radius]);
  }

  @override
  String toString() {
    return 'GamepadButton(name=$name, radius=$radius)';
  }

  Map<String, dynamic> toJson() {
    return GamepadButtonSerializer.toMap(this);
  }
}

@generatedSerializable
class Gamepad extends GamepadEntity {
  Gamepad({
    List<GamepadButtonEntity>? buttons = const [],
    Map<String, dynamic>? dynamicMap,
  }) : buttons = List.unmodifiable(buttons ?? []),
       dynamicMap = Map.unmodifiable(dynamicMap ?? {});

  @override
  List<GamepadButtonEntity>? buttons;

  @override
  Map<String, dynamic>? dynamicMap;

  Gamepad copyWith({
    List<GamepadButtonEntity>? buttons,
    Map<String, dynamic>? dynamicMap,
  }) {
    return Gamepad(
      buttons: buttons ?? this.buttons,
      dynamicMap: dynamicMap ?? this.dynamicMap,
    );
  }

  @override
  bool operator ==(other) {
    return other is GamepadEntity &&
        ListEquality<GamepadButtonEntity>(
          DefaultEquality<GamepadButtonEntity>(),
        ).equals(other.buttons, buttons) &&
        MapEquality<String, dynamic>(
          keys: DefaultEquality<String>(),
          values: DefaultEquality(),
        ).equals(other.dynamicMap, dynamicMap);
  }

  @override
  int get hashCode {
    return Object.hashAll([buttons?.length, dynamicMap?.length]);
  }

  @override
  String toString() {
    return 'Gamepad(buttons=$buttons, dynamicMap=$dynamicMap)';
  }

  Map<String, dynamic> toJson() {
    return GamepadSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const GamepadButtonSerializer gamepadButtonSerializer =
    GamepadButtonSerializer();

class GamepadButtonEncoder extends Converter<GamepadButton, Map> {
  const GamepadButtonEncoder();

  @override
  Map convert(GamepadButton model) => GamepadButtonSerializer.toMap(model);
}

class GamepadButtonDecoder extends Converter<Map, GamepadButton> {
  const GamepadButtonDecoder();

  @override
  GamepadButton convert(Map map) => GamepadButtonSerializer.fromMap(map);
}

class GamepadButtonSerializer extends Codec<GamepadButton, Map> {
  const GamepadButtonSerializer();

  /// The name of the JSON Schema of [GamepadButton].
  static const String schemaName = 'GamepadButton';

  /// The JSON Schema of the map that [toMap] writes of [GamepadButton], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'name': {
        'type': ['string', 'null'],
      },
      'radius': {
        'type': ['integer', 'null'],
      },
    },
  };

  @override
  GamepadButtonEncoder get encoder => const GamepadButtonEncoder();

  @override
  GamepadButtonDecoder get decoder => const GamepadButtonDecoder();

  static GamepadButton fromMap(Map map) {
    return GamepadButton(
      name: map['name'] as String?,
      radius: map['radius'] as int?,
    );
  }

  /// Adds the JSON Schema of [GamepadButton], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(GamepadButtonEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'name': model.name, 'radius': model.radius};
  }
}

abstract class GamepadButtonFields {
  static const List<String> allFields = <String>[name, radius];

  static const String name = 'name';

  static const String radius = 'radius';
}

const GamepadSerializer gamepadSerializer = GamepadSerializer();

class GamepadEncoder extends Converter<Gamepad, Map> {
  const GamepadEncoder();

  @override
  Map convert(Gamepad model) => GamepadSerializer.toMap(model);
}

class GamepadDecoder extends Converter<Map, Gamepad> {
  const GamepadDecoder();

  @override
  Gamepad convert(Map map) => GamepadSerializer.fromMap(map);
}

class GamepadSerializer extends Codec<Gamepad, Map> {
  const GamepadSerializer();

  /// The name of the JSON Schema of [Gamepad].
  static const String schemaName = 'Gamepad';

  /// The JSON Schema of the map that [toMap] writes of [Gamepad], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'buttons': {
        'type': ['array', 'null'],
        'items': {'\$ref': '#/components/schemas/GamepadButton'},
      },
      'dynamic_map': {
        'type': ['object', 'null'],
      },
    },
  };

  @override
  GamepadEncoder get encoder => const GamepadEncoder();

  @override
  GamepadDecoder get decoder => const GamepadDecoder();

  static Gamepad fromMap(Map map) {
    return Gamepad(
      buttons: map['buttons'] is Iterable
          ? List.unmodifiable(
              ((map['buttons'] as Iterable).whereType<Map>()).map(
                GamepadButtonSerializer.fromMap,
              ),
            )
          : [],
      dynamicMap: map['dynamic_map'] is Map
          ? (map['dynamic_map'] as Map).cast<String, dynamic>()
          : {},
    );
  }

  /// Adds the JSON Schema of [Gamepad], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    GamepadButtonSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(GamepadEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'buttons': model.buttons
          ?.map((m) => GamepadButtonSerializer.toMap(m))
          .toList(),
      'dynamic_map': model.dynamicMap,
    };
  }
}

abstract class GamepadFields {
  static const List<String> allFields = <String>[buttons, dynamicMap];

  static const String buttons = 'buttons';

  static const String dynamicMap = 'dynamic_map';
}
