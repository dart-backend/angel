library angel3_json_god.reflection;

import 'dart:mirrors';
import '../angel3_json_god.dart';

const Symbol hashCodeSymbol = #hashCode;
const Symbol runtimeTypeSymbol = #runtimeType;

typedef Serializer(value);
typedef Deserializer(value, {Type? outputType});

List<Symbol> _findGetters(ClassMirror classMirror) {
  List<Symbol> result = [];

  classMirror.instanceMembers
      .forEach((Symbol symbol, MethodMirror methodMirror) {
    if (methodMirror.isGetter &&
        symbol != hashCodeSymbol &&
        symbol != runtimeTypeSymbol) {
      logger.info("Found getter on instance: $symbol");
      result.add(symbol);
    }
  });

  return result;
}

serialize(value, Serializer serializer, [@deprecated bool debug = false]) {
  logger.info("Serializing this value via reflection: $value");
  Map result = {};
  InstanceMirror instanceMirror = reflect(value);
  ClassMirror classMirror = instanceMirror.type;

  // Check for toJson
  for (Symbol symbol in classMirror.instanceMembers.keys) {
    if (symbol == #toJson) {
      logger.info("Running toJson...");
      var result = instanceMirror.invoke(symbol, []).reflectee;
      logger.info("Result of serialization via reflection: $result");
      return result;
    }
  }

  for (Symbol symbol in _findGetters(classMirror)) {
    String name = MirrorSystem.getName(symbol);
    var valueForSymbol = instanceMirror.getField(symbol).reflectee;

    try {
      result[name] = serializer(valueForSymbol);
      logger.info("Set $name to $valueForSymbol");
    } catch (e, st) {
      logger.severe("Could not set $name to $valueForSymbol", e, st);
    }
  }

  logger.info("Result of serialization via reflection: $result");

  return result;
}

deserialize(value, Type outputType, Deserializer deserializer,
    [@deprecated bool debug = false]) {
  logger.info("About to deserialize $value to a $outputType");

  try {
    if (value is List) {
      List<TypeMirror> typeArguments = reflectType(outputType).typeArguments;

      Iterable it;

      if (typeArguments.isEmpty) {
        it = value.map(deserializer);
      } else {
        it = value.map((item) =>
            deserializer(item, outputType: typeArguments[0].reflectedType));
      }

      if (typeArguments.isEmpty) return it.toList();
      logger.info(
          'Casting list elements to ${typeArguments[0].reflectedType} via List.from');

      var mirror = reflectType(List, [typeArguments[0].reflectedType]);

      if (mirror is ClassMirror) {
        var output = mirror.newInstance(#from, [it]).reflectee;
        logger.info('Casted list type: ${output.runtimeType}');
        return output;
      } else {
        throw ArgumentError(
            '${typeArguments[0].reflectedType} is not a class.');
      }
    } else if (value is Map) {
      return _deserializeFromJsonByReflection(value, deserializer, outputType);
    } else {
      return deserializer(value);
    }
  } catch (e, st) {
    logger.severe('Deserialization failed.', e, st);
    rethrow;
  }
}

/// Uses mirrors to deserialize an object.
_deserializeFromJsonByReflection(
    data, Deserializer deserializer, Type outputType) {
  // Check for fromJson
  var typeMirror = reflectType(outputType);

  if (typeMirror is! ClassMirror) {
    throw ArgumentError('$outputType is not a class.');
  }

  var type = typeMirror;
  var fromJson = Symbol('${MirrorSystem.getName(type.simpleName)}.fromJson');

  for (Symbol symbol in type.declarations.keys) {
    if (symbol == fromJson) {
      var decl = type.declarations[symbol];

      if (decl is MethodMirror && decl.isConstructor) {
        logger.info("Running fromJson...");
        var result = type.newInstance(#fromJson, [data]).reflectee;

        logger.info("Result of deserialization via reflection: $result");
        return result;
      }
    }
  }

  ClassMirror classMirror = type;
  InstanceMirror instanceMirror = classMirror.newInstance(Symbol(""), []);

  if (classMirror.isSubclassOf(reflectClass(Map))) {
    var typeArguments = classMirror.typeArguments;

    if (typeArguments.isEmpty ||
        classMirror.typeArguments
            .every((t) => t == currentMirrorSystem().dynamicType)) {
      return data;
    } else {
      var mapType =
          reflectType(Map, typeArguments.map((t) => t.reflectedType).toList())
              as ClassMirror;
      logger.info('Casting this map $data to Map of [$typeArguments]');
      var output = mapType.newInstance(Symbol(''), []).reflectee;

      for (var key in data.keys) {
        output[key] = data[key];
      }

      logger.info('Output: $output of type ${output.runtimeType}');
      return output;
    }
  } else {
    data.keys.forEach((key) {
      try {
        logger.info("Now deserializing value for $key");
        logger.info("data[\"$key\"] = ${data[key]}");
        var deserializedValue = deserializer(data[key]);

        logger.info(
            "I want to set $key to the following ${deserializedValue.runtimeType}: $deserializedValue");
        // Get target type of getter
        Symbol searchSymbol = Symbol(key.toString());
        Symbol symbolForGetter = classMirror.instanceMembers.keys
            .firstWhere((x) => x == searchSymbol);
        Type requiredType = classMirror
            .instanceMembers[symbolForGetter]!.returnType.reflectedType;
        if (data[key].runtimeType != requiredType) {
          logger.info("Currently, $key is a ${data[key].runtimeType}.");
          logger.info("However, $key must be a $requiredType.");

          deserializedValue =
              deserializer(deserializedValue, outputType: requiredType);
        }

        logger.info(
            "Final deserialized value for $key: $deserializedValue <${deserializedValue.runtimeType}>");
        instanceMirror.setField(Symbol(key.toString()), deserializedValue);

        logger.info("Success! $key has been set to $deserializedValue");
      } catch (e, st) {
        logger.severe('Could not set value for field $key.', e, st);
      }
    });
  }

  return instanceMirror.reflectee;
}
