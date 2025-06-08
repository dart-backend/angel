import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:code_builder/code_builder.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

/// Support prefix for base serializable classes.
final List<String> modelPrefix = ['_', 'abstract'];

/// Get the concrete model class name
String getGeneratedModelClassName(String clazz) {
  // Check the supported prefix
  for (var prefix in modelPrefix) {
    if (clazz.toLowerCase().startsWith(prefix)) {
      return clazz.substring(prefix.length);
    }
  }

  return clazz;
}

/// A base context for building serializable classes.
class BuildContext {
  ReCase? _modelClassNameRecase;
  TypeReference? _modelClassType;

  /// A map of fields that are absolutely required, and error messages for when they are absent.
  final Map<String, String> requiredFields = {};

  /// A map of field names to resolved names from `@Alias()` declarations.
  final Map<String, String> aliases = {};

  /// A map of field names to their default values.
  final Map<String, DartObject> defaults = {};

  /// A map of fields to their related information.
  final Map<String, SerializableFieldMirror> fieldInfo = {};

  /// A map of fields that have been marked as to be excluded from serialization.
  // ignore: deprecated_member_use
  final Map<String, Exclude> excluded = {};

  /// A map of "synthetic" fields, i.e. `id` and `created_at` injected automatically.
  final Map<String, bool> shimmed = {};

  final bool autoIdAndDateFields;
  final bool autoSnakeCaseNames;

  final String? originalClassName, sourceFilename;

  /// The fields declared on the original class.
  final List<FieldElement> fields = [];

  final List<ParameterElement> constructorParameters = [];

  final ConstantReader annotation;

  final InterfaceElement clazz;

  /// Any annotations to include in the generated class.
  final List<DartObject> includeAnnotations;

  /// The name of the field that identifies data of this model type.
  String primaryKeyName = 'id';

  BuildContext(this.annotation, this.clazz,
      {this.originalClassName,
      this.sourceFilename,
      this.autoSnakeCaseNames = true,
      this.autoIdAndDateFields = true,
      this.includeAnnotations = const <DartObject>[]});

  /// The name of the generated class.
  String? get modelClassName => getGeneratedModelClassName(originalClassName!);

  /// A [ReCase] instance reflecting on the [modelClassName].
  ReCase get modelClassNameRecase {
    if (modelClassName == null) {
      throw ArgumentError('Model class cannot be null');
    }

    _modelClassNameRecase ??=
        ReCase(getGeneratedModelClassName(modelClassName!));
    return _modelClassNameRecase!;
  }

  TypeReference get modelClassType =>
      _modelClassType ??= TypeReference((b) => b.symbol = modelClassName);

  /// The [FieldElement] pointing to the primary key.
  FieldElement get primaryKeyField =>
      fields.firstWhere((f) => f.name == primaryKeyName);

  bool get importsPackageMeta {
    return clazz.library.definingCompilationUnit.libraryImports.any((element) {
      var uri = element.uri;
      if (uri is DirectiveUriWithLibrary) {
        return uri.relativeUriString == 'package:meta/meta.dart';
      }
      return false;
    });
  }

  /// Get the aliased name (if one is defined) for a field.
  String? resolveFieldName(String name) =>
      aliases.containsKey(name) ? aliases[name] : name;

  /// Finds the type that the field [name] should serialize to.
  DartType resolveSerializedFieldType(String name) {
    return fieldInfo[name]?.serializesTo ??
        fields.firstWhere((f) => f.name == name).type;
  }
}

class SerializableFieldMirror {
  final String? alias;
  final DartObject? defaultValue;
  final Symbol? serializer, deserializer;
  final String? errorMessage;
  final bool isNullable;
  final bool canDeserialize;
  final bool canSerialize;
  final bool exclude;
  final DartType? serializesTo;

  SerializableFieldMirror(
      {this.alias,
      this.defaultValue,
      this.serializer,
      this.deserializer,
      this.errorMessage,
      this.isNullable = false,
      this.canDeserialize = true,
      this.canSerialize = true,
      this.exclude = false,
      this.serializesTo});
}
