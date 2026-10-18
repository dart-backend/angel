library;

import 'dart:async';
import 'dart:typed_data';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
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
  return SharedPartBuilder(const [
    SerializerGenerator(),
  ], 'angel3_serialize_serializer');
}

Builder typescriptDefinitionBuilder(_) {
  return TypeScriptDefinitionBuilder();
}

/// [t] as it is written in Dart, without the `?` of a nullable type.
String _withoutQuestion(DartType t) {
  var name = t.getDisplayString();
  return t.nullabilitySuffix == NullabilitySuffix.question && name.endsWith('?')
      ? name.substring(0, name.length - 1)
      : name;
}

/// Converts a [DartType] to a [TypeReference].
TypeReference convertTypeReference(
  DartType t, {
  bool forceNullable = false,
  bool ignoreNullabilityCheck = false,
}) {
  return TypeReference((b) {
    // A type without an element, as a function type, is as it is written,
    // but its `?`, which isNullable gives.
    b.symbol = t.element?.displayName ?? _withoutQuestion(t);

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

/// The [Serializers] enabled by a `@Serializable` [annotation].
///
/// Each value is read by its `index`, not by the name of the variable it is
/// given by, which may be another constant, as `const js = Serializers.json`.
List<Serializers> readSerializers(ConstantReader annotation) => [
  for (var o in annotation.peek('serializers')?.listValue ?? <DartObject>[])
    if (o.getField('index')?.toIntValue() case var index?)
      Serializers.values[index]
    else
      ?_unreadSerializer(o),
];

/// Logs [o], a value of `serializers` that is not one of [Serializers], which
/// is left out.
Serializers? _unreadSerializer(DartObject o) {
  log.severe(
    'A value of serializers is not one of Serializers, and is left out: '
    '${o.type?.getDisplayString() ?? o}',
  );
  return null;
}

/// [o] as an expression of the code generated in [library], where a
/// constant or a class of a library it imports with a prefix, as
/// `import 'tags.dart' as t;`, has that prefix (`t.Tag.a`).
Expression convertObject(DartObject o, {LibraryElement? library}) {
  Expression convert(DartObject value) =>
      convertObject(value, library: library);

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
    return literalList(o.toListValue()!.map(convert));
  }
  if (o.toMapValue() != null) {
    return literalMap(
      o.toMapValue()!.map((k, v) => MapEntry(convert(k!), convert(v!))),
    );
  }

  var rev = ConstantReader(o).revive();
  // A constant given by a variable or a static field, such as an enum value
  // (`Color.red`) or a top-level constant, has no class in its source, and is
  // that reference, not a call of a constructor.
  if (rev.source.fragment.isEmpty && rev.accessor.isNotEmpty) {
    var prefix = _importPrefix(library, rev.accessor.split('.').first);
    return refer('$prefix${rev.accessor}');
  }
  var className = o.type?.element?.name;
  var prefix = className == null ? '' : _importPrefix(library, className);
  Expression target = prefix.isEmpty
      ? convertTypeReference(o.type!)
      : refer('$prefix$className');
  target = rev.accessor.isEmpty ? target : target.property(rev.accessor);
  return target.call(
    rev.positionalArguments.map(convert),
    rev.namedArguments.map((k, v) => MapEntry(k, convert(v))),
  );
}

/// The prefix, with its `.`, of the import of [library] by which it has
/// [name], a class or top-level constant, or `''` if it has it without one.
String _importPrefix(LibraryElement? library, String name) {
  if (library == null ||
      library.firstFragment.scope.lookup(name).getter != null) {
    return '';
  }
  for (var fragment in library.fragments) {
    for (var import in fragment.libraryImports) {
      var prefix = import.prefix?.name;
      // Of the names the imported library exports, as the namespace of a
      // prefixed import has them by its prefix.
      if (prefix != null &&
          import.importedLibrary?.exportNamespace.get2(name) != null) {
        return '$prefix.';
      }
    }
  }
  return '';
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
  if (type is InterfaceType && type.element is EnumElement) {
    // Find the index of the enum, then find the member.
    for (var field in type.element.fields) {
      if (field.isEnumConstant && field.isStatic) {
        var value = type.element.getField(field.name!)!.computeConstantValue();
        if (v is Enum && value is Enum) {
          var v2 = v as Enum;
          var value2 = value as Enum;

          if (value2.name == v2.name) {
            return '${type.element.displayName}.${field.name}';
          }
        } else {
          if (value == v) {
            return '${type.element.displayName}.${field.name}';
          }
        }
      }
    }
  }

  throw ArgumentError(v.toString());
}

/// Determines if a type supports `package:angel3_serialize`.
bool isModelClass(DartType? t) {
  if (t == null) return false;

  if (serializableTypeChecker.hasAnnotationOf(t.element!)) {
    return true;
  }

  if (generatedSerializableTypeChecker.hasAnnotationOf(t.element!)) {
    return true;
  }

  // TODO: Changing to typeNamed() will cause an exception in source_gen
  DartType d = t;

  if (TypeChecker.typeNamed(
    Model,
    inPackage: 'angel3_serialize',
  ).isAssignableFromType(d)) {
    return true;
  }

  if (t is InterfaceType) {
    return isModelClass(t.superclass);
  } else {
    return false;
  }
}

bool isListType(DartType t) {
  return const TypeChecker.typeNamed(List).isAssignableFromType(t) &&
      !const TypeChecker.typeNamed(Uint8List).isAssignableFromType(t);
}

bool isMapType(DartType t) {
  return const TypeChecker.typeNamed(Map).isAssignableFromType(t) &&
      !const TypeChecker.typeNamed(Uint8List).isAssignableFromType(t);
}

bool isListOrMapType(DartType t) {
  return (const TypeChecker.typeNamed(List).isAssignableFromType(t) ||
          const TypeChecker.typeNamed(Map).isAssignableFromType(t)) &&
      !const TypeChecker.typeNamed(Uint8List).isAssignableFromType(t);
}

bool isEnumType(DartType t) {
  if (t is InterfaceType) {
    return t.element is Enum;
  }

  return false;
}

/// Determines if a [DartType] is a `List` with the first type argument being a `Model`.
bool isListOfModelType(InterfaceType t) {
  return const TypeChecker.typeNamed(List).isAssignableFromType(t) &&
      t.typeArguments.length == 1 &&
      isModelClass(t.typeArguments[0]);
}

/// Determines if a [DartType] is a `Map` with the second type argument being a `Model`.
bool isMapToModelType(InterfaceType t) {
  return const TypeChecker.typeNamed(Map).isAssignableFromType(t) &&
      t.typeArguments.length == 2 &&
      isModelClass(t.typeArguments[1]);
}

bool isAssignableToModel(DartType type) =>
    const TypeChecker.typeNamed(Model).isAssignableFromType(type);

/// Compute a [String] representation of a [type].
String? typeToString(DartType type) {
  if (type is InterfaceType) {
    if (type.typeArguments.isEmpty) {
      return type.element.displayName;
    }

    var name = type.element.displayName;

    return '$name<${type.typeArguments.map(typeToString).join(', ')}>';
  } else {
    return type.element?.displayName;
  }
}
