library;

import 'dart:async';
import 'dart:mirrors';
import 'dart:typed_data';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:build/build.dart';
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart' hide LibraryBuilder;

import 'build_context.dart';
import 'context.dart';

part 'model.dart';

part 'serialize.dart';

part 'typescript.dart';

Builder jsonModelBuilder(_) {
  return SharedPartBuilder(const [JsonModelGenerator()], 'angel3_serialize');
}

Builder serializerBuilder(_) {
  return SharedPartBuilder(
      const [SerializerGenerator()], 'angel3_serialize_serializer');
}

Builder typescriptDefinitionBuilder(_) {
  return TypeScriptDefinitionBuilder();
}

/// Converts a [DartType] to a [TypeReference].
TypeReference convertTypeReference(DartType t,
    {bool forceNullable = false, bool ignoreNullabilityCheck = false}) {
  return TypeReference((b) {
    b.symbol = t.element3?.displayName;

    // Generate nullable type
    if (ignoreNullabilityCheck) {
      b.isNullable = false;
    } else {
      if (t.nullabilitySuffix == NullabilitySuffix.question || forceNullable) {
        b.isNullable = true;
      }
    }

    if (t is InterfaceType) {
      b.types.addAll(t.typeArguments.map(convertTypeReference));
    }
  });
}

Expression convertObject(DartObject o) {
  if (o.isNull) return literalNull;
  if (o.toBoolValue() != null) return literalBool(o.toBoolValue()!);
  if (o.toIntValue() != null) return literalNum(o.toIntValue()!);
  if (o.toDoubleValue() != null) return literalNum(o.toDoubleValue()!);
  if (o.toSymbolValue() != null) {
    return CodeExpression(Code('#${o.toSymbolValue()!}'));
  }
  if (o.toStringValue() != null) return literalString(o.toStringValue()!);
  if (o.toTypeValue() != null) return convertTypeReference(o.toTypeValue()!);
  if (o.toListValue() != null) {
    return literalList(o.toListValue()!.map(convertObject));
  }
  if (o.toMapValue() != null) {
    return literalMap(o
        .toMapValue()!
        .map((k, v) => MapEntry(convertObject(k!), convertObject(v!))));
  }

  var rev = ConstantReader(o).revive();
  Expression target = convertTypeReference(o.type!);
  target = rev.accessor.isEmpty ? target : target.property(rev.accessor);
  return target.call(rev.positionalArguments.map(convertObject),
      rev.namedArguments.map((k, v) => MapEntry(k, convertObject(v))));
}

String? dartObjectToString(DartObject v) {
  var type = v.type;
  if (v.isNull) return 'null';
  if (v.toBoolValue() != null) {
    return v.toBoolValue().toString();
  }
  if (v.toIntValue() != null) {
    return v.toIntValue().toString();
  }
  if (v.toDoubleValue() != null) {
    return v.toDoubleValue().toString();
  }
  if (v.toSymbolValue() != null) {
    return '#${v.toSymbolValue()!}';
  }
  if (v.toTypeValue() != null) {
    return v.toTypeValue()!.getDisplayString();
  }
  if (v.toListValue() != null) {
    return 'const [${v.toListValue()!.map(dartObjectToString).join(', ')}]';
  }
  if (v.toMapValue() != null) {
    return 'const {${v.toMapValue()!.entries.map((entry) {
      var k = dartObjectToString(entry.key!);
      var v = dartObjectToString(entry.value!);
      return '$k: $v';
    }).join(', ')}}';
  }
  if (v.toStringValue() != null) {
    return literalString(v.toStringValue()!)
        .accept(DartEmitter(useNullSafetySyntax: true))
        .toString();
  }
  if (type is InterfaceType && type.element3 is EnumElement2) {
    // Find the index of the enum, then find the member.
    for (var field in type.element.fields) {
      if (field.isEnumConstant && field.isStatic) {
        var value = type.element.getField(field.name)!.computeConstantValue();
        if (v is Enum && value is Enum) {
          var v2 = v as Enum;
          var value2 = value as Enum;

          if (value2.name == v2.name) {
            return '${type.element3.displayName}.${field.name}';
          }
        } else {
          if (value == v) {
            return '${type.element3.displayName}.${field.name}';
          }
        }
      }
    }
  }

  throw ArgumentError(v.toString());
}

/// Determines if a type supports `package:angel_serialize`.
bool isModelClass(DartType? t) {
  if (t == null) return false;

  if (serializableTypeChecker.hasAnnotationOf(t.element!)) {
    return true;
  }

  if (generatedSerializableTypeChecker.hasAnnotationOf(t.element!)) {
    return true;
  }

  if (const TypeChecker.fromRuntime(Model).isAssignableFromType(t)) {
    return true;
  }

  if (t is InterfaceType) {
    return isModelClass(t.superclass);
  } else {
    return false;
  }
}

bool isListType(DartType t) {
  return const TypeChecker.fromRuntime(List).isAssignableFromType(t) &&
      !const TypeChecker.fromRuntime(Uint8List).isAssignableFromType(t);
}

bool isMapType(DartType t) {
  return const TypeChecker.fromRuntime(Map).isAssignableFromType(t) &&
      !const TypeChecker.fromRuntime(Uint8List).isAssignableFromType(t);
}

bool isListOrMapType(DartType t) {
  return (const TypeChecker.fromRuntime(List).isAssignableFromType(t) ||
          const TypeChecker.fromRuntime(Map).isAssignableFromType(t)) &&
      !const TypeChecker.fromRuntime(Uint8List).isAssignableFromType(t);
}

bool isEnumType(DartType t) {
  if (t is InterfaceType) {
    return t.element3 is Enum;
  }

  return false;
}

/// Determines if a [DartType] is a `List` with the first type argument being a `Model`.
bool isListOfModelType(InterfaceType t) {
  return const TypeChecker.fromRuntime(List).isAssignableFromType(t) &&
      t.typeArguments.length == 1 &&
      isModelClass(t.typeArguments[0]);
}

/// Determines if a [DartType] is a `Map` with the second type argument being a `Model`.
bool isMapToModelType(InterfaceType t) {
  return const TypeChecker.fromRuntime(Map).isAssignableFromType(t) &&
      t.typeArguments.length == 2 &&
      isModelClass(t.typeArguments[1]);
}

bool isAssignableToModel(DartType type) =>
    const TypeChecker.fromRuntime(Model).isAssignableFromType(type);

/// Compute a [String] representation of a [type].
String? typeToString(DartType type) {
  if (type is InterfaceType) {
    if (type.typeArguments.isEmpty) {
      return type.element3.displayName;
    }

    var name = type.element3.displayName;

    return '$name<${type.typeArguments.map(typeToString).join(', ')}>';
  } else {
    return type.element3?.displayName;
  }
}
