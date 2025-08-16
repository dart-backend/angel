import 'dart:async';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart';

import 'package:analyzer/dart/element/type.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/element/element.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';
import 'context.dart';

// ignore: deprecated_member_use
//const TypeChecker aliasTypeChecker = TypeChecker.fromRuntime(Alias);

const TypeChecker dateTimeTypeChecker = TypeChecker.fromRuntime(DateTime);

// ignore: deprecated_member_use
const TypeChecker excludeTypeChecker = TypeChecker.fromRuntime(Exclude);

const TypeChecker serializableFieldTypeChecker = TypeChecker.fromRuntime(
  SerializableField,
);

const TypeChecker serializableTypeChecker = TypeChecker.fromRuntime(
  Serializable,
);

const TypeChecker generatedSerializableTypeChecker = TypeChecker.fromRuntime(
  GeneratedSerializable,
);

final Map<String, BuildContext> _cache = {};

/// Create a [BuildContext].
Future<BuildContext?> buildContext(
  InterfaceElement2 clazz,
  ConstantReader annotation,
  BuildStep buildStep,
  Resolver resolver,
  bool autoSnakeCaseNames, {
  bool heedExclude = true,
}) async {
  var id = clazz.location.components.join('-');
  if (_cache.containsKey(id)) {
    return _cache[id];
  }

  // Check for autoIdAndDateFields, autoSnakeCaseNames
  autoSnakeCaseNames =
      annotation.peek('autoSnakeCaseNames')?.boolValue ?? autoSnakeCaseNames;

  var ctx = BuildContext(
    annotation,
    clazz,
    originalClassName: clazz.name3,
    sourceFilename: p.basename(buildStep.inputId.path),
    autoSnakeCaseNames: autoSnakeCaseNames,
    includeAnnotations:
        annotation.peek('includeAnnotations')?.listValue ?? <DartObject>[],
  );
  // var lib = await resolver.libraryFor(buildStep.inputId);
  var fields = <FieldElement2>[];
  var fieldNames = <String>[];

  for (var field in fields) {
    fieldNames.add(field.name3!);
  }

  // Crawl for classes from parent classes.
  void crawlClass(InterfaceType? t) {
    while (t != null) {
      // Check and skip fields with same name
      var parentClassFields = <FieldElement2>[];
      for (var el in t.element3.fields2) {
        if (fieldNames.contains(el.name3)) {
          continue;
        }
        parentClassFields.add(el);
        fieldNames.add(el.name3!);
      }

      fields.insertAll(0, parentClassFields);
      t.interfaces.forEach(crawlClass);
      t = t.superclass;
    }

    // Move id field to the front if exist
    var item = fields.firstWhereOrNull((el) => el.name3 == 'id');
    if (item != null) {
      fields.removeWhere((el) => el.name3 == 'id');
      fields.insert(0, item);
    }
  }

  crawlClass(clazz.thisType);

  for (var field in fields) {
    // Skip private fields
    if (field.name3?.startsWith('_') == true) {
      continue;
    }

    if (field.getter2 != null &&
        (field.setter2 != null || field.getter2!.isAbstract)) {
      var el = field.setter2 == null ? field.getter2! : field;
      //fieldNames.add(field.name);

      // Check for @SerializableField
      var fieldAnn = serializableFieldTypeChecker.firstAnnotationOf(el);

      void handleSerializableField(SerializableFieldMirror sField) {
        ctx.fieldInfo[field.name3!] = sField;

        if (sField.defaultValue != null) {
          ctx.defaults[field.name3!] = sField.defaultValue!;
        }

        if (sField.alias != null) {
          ctx.aliases[field.name3!] = sField.alias!;
        } else if (autoSnakeCaseNames != false) {
          ctx.aliases[field.name3!] = ReCase(field.name3!).snakeCase;
        }

        if (sField.isNullable == false) {
          var reason =
              sField.errorMessage ??
              "Missing required field '${ctx.resolveFieldName(field.name3!)}' on ${ctx.modelClassName}.";
          ctx.requiredFields[field.name3!] = reason;
        }

        if (sField.exclude) {
          // ignore: deprecated_member_use
          ctx.excluded[field.name3!] = Exclude(
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
          serializer: cr.peek('serializer')?.symbolValue,
          deserializer: cr.peek('deserializer')?.symbolValue,
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
          ctx.excluded[field.name3!] = Exclude(
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
            serializer: f.serializer,
            deserializer: f.deserializer,
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

  // Get constructor params, if any
  ctx.constructorParameters.addAll(clazz.unnamedConstructor2!.formalParameters);

  return ctx;
}

/// A manually-instantiated [FieldElement2].
class ShimFieldImpl extends FieldElementImpl {
  //@override
  //final DartType type;

  ShimFieldImpl(String name, dynamic shimFieldType) : super(name, -1) {
    type = shimFieldType;
  }
}
