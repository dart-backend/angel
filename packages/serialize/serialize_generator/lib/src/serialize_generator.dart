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
import 'package:code_builder/code_builder.dart' hide FunctionType, RecordType;
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

/// Converts a [DartType] to a [TypeReference], as [typeIn] writes it in code
/// generated in [library]: with the prefix of the import of its class, and
/// its type arguments.
TypeReference convertTypeReference(
  DartType t, {
  bool forceNullable = false,
  bool ignoreNullabilityCheck = false,
  LibraryElement? library,
}) {
  return TypeReference((b) {
    b.symbol = typeIn(t, library, false);

    // Generate nullable type
    if (ignoreNullabilityCheck) {
      b.isNullable = false;
    } else {
      if (t.nullabilitySuffix == NullabilitySuffix.question || forceNullable) {
        b.isNullable = true;
      }
    }
  });
}

/// The [Serializers] enabled by a `@Serializable` [annotation].
///
/// Each value is read as the value it is, by its name, not by the name of the
/// variable it is given by, which may be another constant, as
/// `const js = Serializers.json`. A value that is not one of [Serializers] is
/// left out, and with [report] logged as an error, which only the model
/// builder, of the builders that each read them, reports, as every model runs
/// it.
List<Serializers> readSerializers(
  ConstantReader annotation, {
  bool report = false,
}) => [
  for (var o in annotation.peek('serializers')?.listValue ?? <DartObject>[])
    if (_serializerOf(o) case var serializer?)
      serializer
    else if (report)
      ?_unreadSerializer(o),
];

/// The [Serializers] value of [o], by its name, as the generator may be of
/// another version of `angel3_serialize`, whose values are in another order,
/// or by its index if it has no name, if [Serializers] has one of it.
Serializers? _serializerOf(DartObject o) {
  var name = o.getField('_name')?.toStringValue();
  if (name != null) {
    return Serializers.values.where((s) => s.name == name).firstOrNull;
  }
  var index = o.getField('index')?.toIntValue();
  return index != null && index >= 0 && index < Serializers.values.length
      ? Serializers.values[index]
      : null;
}

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
  if (o.toTypeValue() != null) {
    return convertTypeReference(o.toTypeValue()!, library: library);
  }
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
    var first = rev.accessor.split('.').first;
    // Of the class of the value, as `Tag` of `Tag.a`, which the name is of.
    var element = o.type?.element;
    var prefix = _importPrefix(
      library,
      first,
      element?.name == first ? element : null,
    );
    return refer('$prefix${rev.accessor}');
  }
  // With the prefix of its import, and its type arguments with theirs, as
  // `t.Ann<t.Tag>`.
  Expression target = convertTypeReference(o.type!, library: library);
  target = rev.accessor.isEmpty ? target : target.property(rev.accessor);
  return target.call(
    rev.positionalArguments.map(convert),
    rev.namedArguments.map((k, v) => MapEntry(k, convert(v))),
  );
}

/// The prefix, with its `.`, of the import of [library] by which it has
/// [name], a class or top-level constant, as [element] if it is given, or
/// `''` if it has it without one.
///
/// An import's names are those its `show` and `hide` leave, and a name of
/// [library] itself, or of an import without a prefix, is the one it has
/// without a prefix only if it is [element], not another of the same name.
String _importPrefix(LibraryElement? library, String name, [Element? element]) {
  if (library == null) return '';
  bool isElement(Element? found) =>
      found != null &&
      (element == null || found == element || found.baseElement == element);
  if (isElement(library.firstFragment.scope.lookup(name).getter)) return '';
  for (var fragment in library.fragments) {
    for (var import in fragment.libraryImports) {
      var prefix = import.prefix?.name;
      if (prefix != null && isElement(import.namespace.definedNames2[name])) {
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

/// The name of the class generated of the model of [type], as the model
/// class itself is named: a class generated already (`@generatedSerializable`)
/// is its own, and a model class is [generatedClassNameOf] its name, as it is
/// declared: `User` of `_UserEntity`, `EntityType` of `_EntityType`, and `Url`
/// of `_URL`.
String modelClassNameOf(DartType type) {
  var element = type.element!;
  var name = element.name!;
  return generatedSerializableTypeChecker.hasAnnotationOf(element)
      ? name
      : generatedClassNameOf(name);
}

/// Determines if a type supports `package:angel3_serialize`.
bool isModelClass(DartType? t) {
  // A type without an element, as a function type, is no model.
  if (t == null || t.element == null) return false;

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
/// [type] as it is written in code generated in [library], without its own
/// `?`, which the caller gives; its type arguments keep theirs.
String? typeToString(DartType type, [LibraryElement? library]) =>
    typeIn(type, library, false);

/// [type] as it is written in code generated in [library], with its `?` if
/// [question]: a class with the prefix of its import if it is of a library
/// imported with one (`t.Tag`), its type arguments, and the types of a function
/// type (`void Function(t.Tag)`) or a record (`(int, t.Tag)`) as well. A
/// generic function type, and another type, as `dynamic` or a type parameter,
/// are as the analyzer writes them.
String typeIn(DartType type, [LibraryElement? library, bool question = true]) {
  var mark = question && type.nullabilitySuffix == NullabilitySuffix.question
      ? '?'
      : '';
  String of(DartType t) => typeIn(t, library);
  if (type is InterfaceType) {
    var name = type.element.name ?? type.element.displayName;
    var prefix = _importPrefix(library, name, type.element);
    var arguments = type.typeArguments.isEmpty
        ? ''
        : '<${type.typeArguments.map(of).join(', ')}>';
    return '$prefix$name$arguments$mark';
  }
  if (type is FunctionType && type.typeParameters.isEmpty) {
    var parameters = type.formalParameters;
    var optional = [
      for (var p in parameters)
        if (p.isOptionalPositional) of(p.type),
    ];
    var named = [
      for (var p in parameters)
        if (p.isNamed)
          '${p.isRequiredNamed ? 'required ' : ''}${of(p.type)} ${p.name}',
    ];
    var list = [
      for (var p in parameters)
        if (p.isRequiredPositional) of(p.type),
      if (optional.isNotEmpty) '[${optional.join(', ')}]',
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ];
    var function = '${of(type.returnType)} Function(${list.join(', ')})';
    // The `?` of a nullable function type is of it, as `void Function()?`.
    return '$function$mark';
  }
  if (type is RecordType) {
    var positional = type.positionalFields.map((f) => of(f.type)).toList();
    var named = [for (var f in type.namedFields) '${of(f.type)} ${f.name}'];
    var fields = [
      ...positional,
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ].join(', ');
    // A record of one positional field has a comma, as `(int,)`.
    var comma = positional.length == 1 && named.isEmpty ? ',' : '';
    return '($fields$comma)$mark';
  }
  return question ? type.getDisplayString() : _withoutQuestion(type);
}
