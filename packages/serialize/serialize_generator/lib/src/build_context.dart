import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/element/element.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/element/type.dart';

// ignore: implementation_imports
import 'package:analyzer/src/summary2/reference.dart';

import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'context.dart';

// ignore: deprecated_member_use
//const TypeChecker aliasTypeChecker = TypeChecker.fromRuntime(Alias);

const TypeChecker dateTimeTypeChecker = TypeChecker.typeNamed(DateTime);

// ignore: deprecated_member_use
const TypeChecker excludeTypeChecker = TypeChecker.typeNamed(Exclude);

const TypeChecker serializableFieldTypeChecker = TypeChecker.typeNamed(
  SerializableField,
);

const TypeChecker serializableTypeChecker = TypeChecker.typeNamed(Serializable);

const TypeChecker generatedSerializableTypeChecker = TypeChecker.typeNamed(
  GeneratedSerializable,
);

final Map<String, BuildContext> _cache = {};

/// Create a [BuildContext].
Future<BuildContext?> buildContext(
  InterfaceElement clazz,
  ConstantReader annotation,
  BuildStep buildStep,
  Resolver resolver,
  bool autoSnakeCaseNames, {
  bool heedExclude = true,
}) async {
  // var id = clazz.location.components.join('-');
  var id = "${clazz.library.baseElement}-${clazz.displayName}";
  //print("==> id=[$id]");

  if (_cache.containsKey(id)) {
    return _cache[id];
  }

  // Check for autoIdAndDateFields, autoSnakeCaseNames
  autoSnakeCaseNames =
      annotation.peek('autoSnakeCaseNames')?.boolValue ?? autoSnakeCaseNames;

  var ctx = BuildContext(
    annotation,
    clazz,
    originalClassName: clazz.name,
    sourceFilename: p.basename(buildStep.inputId.path),
    autoSnakeCaseNames: autoSnakeCaseNames,
    includeAnnotations: _includeAnnotations(clazz, annotation),
  );
  // var lib = await resolver.libraryFor(buildStep.inputId);
  var fields = <FieldElement>[];
  var fieldNames = <String>[];

  for (var field in fields) {
    fieldNames.add(field.name!);
  }

  // Crawl for classes from parent classes.
  void crawlClass(InterfaceType? t) {
    while (t != null) {
      // Check and skip fields with same name
      var parentClassFields = <FieldElement>[];
      for (var el in t.element.fields) {
        if (fieldNames.contains(el.name)) {
          continue;
        }
        parentClassFields.add(el);
        fieldNames.add(el.name!);
      }

      fields.insertAll(0, parentClassFields);
      t.interfaces.forEach(crawlClass);
      t = t.superclass;
    }

    // Move id field to the front if exist
    var item = fields.firstWhereOrNull((el) => el.name == 'id');
    if (item != null) {
      fields.removeWhere((el) => el.name == 'id');
      fields.insert(0, item);
    }
  }

  crawlClass(clazz.thisType);

  for (var field in fields) {
    // Skip private fields
    if (field.name?.startsWith('_') == true) {
      continue;
    }

    if (field.getter != null &&
        (field.setter != null || field.getter!.isAbstract)) {
      var el = field.setter == null ? field.getter! : field;
      //fieldNames.add(field.name);

      // Check for @SerializableField
      var fieldAnn = serializableFieldTypeChecker.firstAnnotationOf(el);

      void handleSerializableField(SerializableFieldMirror sField) {
        ctx.fieldInfo[field.name!] = sField;

        if (sField.defaultValue != null) {
          ctx.defaults[field.name!] = sField.defaultValue!;
        }

        if (sField.alias != null) {
          ctx.aliases[field.name!] = sField.alias!;
        } else if (autoSnakeCaseNames != false) {
          ctx.aliases[field.name!] = ReCase(field.name!).snakeCase;
        }

        if (sField.isNullable == false) {
          var reason =
              sField.errorMessage ??
              "Missing required field '${ctx.resolveFieldName(field.name!)}' on ${ctx.modelClassName}.";
          ctx.requiredFields[field.name!] = reason;
        }

        if (sField.exclude) {
          // ignore: deprecated_member_use
          ctx.excluded[field.name!] = Exclude(
            canSerialize: sField.canSerialize,
            canDeserialize: sField.canDeserialize,
          );
        }
      }

      if (fieldAnn != null) {
        var cr = ConstantReader(fieldAnn);
        var excluded = cr.peek('exclude')?.boolValue ?? false;
        var sField = SerializableFieldMirror(
          alias: cr.peek('alias')?.stringValue,
          defaultValue: cr.peek('defaultValue')?.objectValue,
          serializer: cr.peek('serializer')?.objectValue.toSymbolValue(),
          deserializer: cr.peek('deserializer')?.objectValue.toSymbolValue(),
          errorMessage: cr.peek('errorMessage')?.stringValue,
          isNullable: cr.peek('isNullable')?.boolValue ?? !excluded,
          canDeserialize: cr.peek('canDeserialize')?.boolValue ?? false,
          canSerialize: cr.peek('canSerialize')?.boolValue ?? false,
          exclude: excluded,
          serializesTo: cr.peek('serializesTo')?.typeValue,
        );

        handleSerializableField(sField);

        // Apply
      } else {
        var foundNone = true;
        // Skip if annotated with @exclude
        var excludeAnnotation = excludeTypeChecker.firstAnnotationOf(el);

        if (excludeAnnotation != null) {
          var cr = ConstantReader(excludeAnnotation);
          foundNone = false;

          // ignore: deprecated_member_use
          ctx.excluded[field.name!] = Exclude(
            canSerialize: cr.read('canSerialize').boolValue,
            canDeserialize: cr.read('canDeserialize').boolValue,
          );
        }

        // Check for @DefaultValue()
        /*
        var defAnn =
            // ignore: deprecated_member_use
            const TypeChecker.fromRuntime(DefaultValue).firstAnnotationOf(el);
        if (defAnn != null) {
          var rev = ConstantReader(defAnn).revive().positionalArguments[0];
          ctx.defaults[field.name] = rev;
          foundNone = false;
        }
        */

        // Check for alias
        // ignore: deprecated_member_use
        /*
        Alias? alias;
        var aliasAnn = aliasTypeChecker.firstAnnotationOf(el);

        if (aliasAnn != null) {
          // ignore: deprecated_member_use
          alias = Alias(aliasAnn.getField('name')!.toStringValue()!);
          foundNone = false;
        }
        

        if (alias?.name.isNotEmpty == true) {
          ctx.aliases[field.name] = alias!.name;
        } else if (autoSnakeCaseNames != false) {
          ctx.aliases[field.name] = ReCase(field.name).snakeCase;
        }
        */

        // Check for @required

        //var required = const TypeChecker.fromRuntime(
        //  Required,
        //).firstAnnotationOf(el);

        /*
        if (required != null) {
          log.warning(
            'Using @required on fields (like ${clazz.name}.${field.name}) is now deprecated; use @SerializableField(isNullable: false) instead.',
          );
          var cr = ConstantReader(required);
          var reason =
              cr.peek('reason')?.stringValue ??
              "Missing required field '${ctx.resolveFieldName(field.name)}' on ${ctx.modelClassName}.";
          ctx.requiredFields[field.name] = reason;
          foundNone = false;
        }
        */

        if (foundNone) {
          var f = SerializableField();
          var sField = SerializableFieldMirror(
            alias: f.alias,
            defaultValue: null,
            // A default SerializableField has neither.
            serializer: null,
            deserializer: null,
            errorMessage: f.errorMessage,
            isNullable: f.isNullable,
            canDeserialize: f.canDeserialize,
            canSerialize: f.canSerialize,
            exclude: f.exclude,
            serializesTo: null,
          );
          handleSerializableField(sField);
        }
      }

      ctx.fields.add(field);
    }
  }

  // Get constructor params, if any. A class may have only named constructors,
  // as a `@graphQLClass` that is not a model.
  ctx.constructorParameters.addAll(
    clazz.unnamedConstructor?.formalParameters ?? const [],
  );

  return ctx;
}

/// A manually-instantiated [FieldElement].
@Deprecated(
  'Subclasses analyzer internals, which change between versions; '
  'angel3_orm_generator no longer uses it.',
)
class ShimFieldImpl extends FieldElementImpl {
  //@override
  //final DartType type;

  ShimFieldImpl(
    TypeImpl shimFieldType,
    Reference shimFieldRef,
    FieldFragmentImpl firstFragment,
  ) : super(
        reference: _memberReference(shimFieldRef, firstFragment.name ?? 'shim'),
        firstFragment: firstFragment,
      ) {
    type = shimFieldType;
  }

  /// [reference] if it is a member's; otherwise (e.g. a [RootReference]) a
  /// member reference for [name] in a reference tree of its own.
  ///
  /// The analyzer requires a [MemberReference], which only it can create, and
  /// its constructor points the reference at this element, so a reference
  /// from the analyzer's own tree must not be used for a shim.
  static MemberReference _memberReference(Reference reference, String name) =>
      reference is MemberReference
      ? reference
      : RootReference()
            .getOrCreateLibrary(Uri.parse('angel3-shim:///$name'))
            .getOrCreateClass('Shim')
            .declareField(name);
}

/// Whether [value] is an instance of a class or an enum, which may be an
/// annotation: not `null`, nor a literal, such as a string, a list or a
/// function, which no annotation is.
bool _isAnnotation(DartObject value) {
  if (value.isNull) return false;
  var element = value.type?.element;
  if (element is! ClassElement && element is! EnumElement) return false;
  return value.toBoolValue() == null &&
      value.toIntValue() == null &&
      value.toDoubleValue() == null &&
      value.toStringValue() == null &&
      value.toSymbolValue() == null &&
      value.toTypeValue() == null &&
      value.toListValue() == null &&
      value.toMapValue() == null &&
      value.toSetValue() == null &&
      value.toFunctionValue() == null &&
      value.toRecordValue() == null;
}

/// The `includeAnnotations` of a `@Serializable` [annotation] on [clazz],
/// each of which must be a constant instance of a class (not, e.g., a string),
/// as the generated class carries it as an annotation: a call of a const
/// constructor, or a reference to a constant, such as an enum value.
List<DartObject> _includeAnnotations(
  InterfaceElement clazz,
  ConstantReader annotation,
) {
  var values = annotation.peek('includeAnnotations')?.listValue ?? [];
  for (var value in values) {
    // A value of an extension type is of its representation type, as the
    // analyzer gives it, so `Tag(1)` of `extension type const Tag(int v)` is
    // an int, which is rejected as one.
    if (!_isAnnotation(value)) {
      throw InvalidGenerationSourceError(
        'Every value in includeAnnotations must be a constant instance of a '
        'class, to be used as an annotation on the generated class; '
        '${value.type?.getDisplayString() ?? 'null'} is not.',
        element: clazz,
      );
    }
  }
  return values;
}
