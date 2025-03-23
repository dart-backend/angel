import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:angel3_serialize_generator/build_context.dart';
import 'package:angel3_serialize_generator/context.dart';
import 'package:build/build.dart';
import 'package:inflection3/inflection3.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'readers.dart';

bool isHasRelation(Relationship r) =>
    r.type == RelationshipType.hasOne || r.type == RelationshipType.hasMany;

bool isSpecialId(OrmBuildContext ctx, FieldElement field) {
  return
      // field is ShimFieldImpl &&
      field is! RelationFieldImpl &&
          (field.name == 'id' &&
              const TypeChecker.fromRuntime(Model)
                  .isAssignableFromType(ctx.buildContext.clazz.thisType));
}

Element _findElement(FieldElement field) {
  return (field.setter == null ? field.getter : field) ?? field;
}

FieldElement? findPrimaryFieldInList(
    OrmBuildContext ctx, Iterable<FieldElement> fields) {
  for (var field_ in fields) {
    var field = field_ is RelationFieldImpl ? field_.originalField : field_;
    var element = _findElement(field);
    // print(
    //     'Searching in ${ctx.buildContext.originalClassName}=>${field?.name} (${field.runtimeType})');
    // Check for column annotation...
    var columnAnnotation = columnTypeChecker.firstAnnotationOf(element);

    if (columnAnnotation != null) {
      var column = reviveColumn(ConstantReader(columnAnnotation));
      // print(
      //     '  * Found column on ${field.name} with indexType = ${column.indexType}');
      // print(element.metadata);
      if (column.indexType == IndexType.primaryKey) return field;
    }
  }

  var specialId = fields.firstWhereOrNull((f) => isSpecialId(ctx, f));
  // print(
  //     'Special ID on ${ctx.buildContext.originalClassName} => ${specialId?.name}');
  return specialId;
}

/// Create ORM Context
Future<OrmBuildContext?> buildOrmContext(
    Map<String, OrmBuildContext> cache,
    InterfaceElement clazz,
    ConstantReader annotation,
    BuildStep buildStep,
    Resolver resolver,
    bool? autoSnakeCaseNames,
    {bool heedExclude = true}) async {
  // Check for @generatedSerializable
  // ignore: unused_local_variable
  DartObject? generatedSerializable;

  while ((generatedSerializable =
          const TypeChecker.fromRuntime(GeneratedSerializable)
              .firstAnnotationOf(clazz)) !=
      null) {
    if (clazz.supertype != null) {
      clazz = clazz.supertype!.element;
    }
  }

  var id = clazz.location?.components.join('-') ?? '';
  if (cache.containsKey(id)) {
    return cache[id];
  }
  var buildCtx = await buildContext(
      clazz, annotation, buildStep, resolver, autoSnakeCaseNames!,
      heedExclude: heedExclude);
  var ormAnnotation = reviveORMAnnotation(annotation);
  // print(
  //     'tableName (${annotation.objectValue.type.name}) => ${ormAnnotation.tableName} from ${clazz.name} (${annotation.revive().namedArguments})');
  if (buildCtx == null) {
    log.severe('BuildContext is null');

    return null;
  }
  var ctx = OrmBuildContext(
      buildCtx,
      ormAnnotation,
      (ormAnnotation.tableName?.isNotEmpty == true)
          ? ormAnnotation.tableName
          : pluralize(ReCase(clazz.name).snakeCase));
  cache[id] = ctx;

  // Read all fields
  for (var field in buildCtx.fields) {
    // Check for column annotation...
    var element = _findElement(field);
    var columnAnnotation = columnTypeChecker.firstAnnotationOf(element);

    Column? column;
    if (columnAnnotation != null) {
      // print('[ORM_BUILD_CONTEXT] ${element.name} => $columnAnnotation');
      column = reviveColumn(ConstantReader(columnAnnotation));
    }

    if (column == null && isSpecialId(ctx, field)) {
      // This is only for PostgreSQL, so implementations without a `serial` type
      // must handle it accordingly, of course.
      column = const Column(
          type: ColumnType.serial, indexType: IndexType.primaryKey);
    }

    column ??= Column(
      type: inferColumnType(
        buildCtx.resolveSerializedFieldType(field.name),
      ),
    );
    var isEnumField =
        (field.type is InterfaceType && field.type.element is EnumElement);
    var hasColumnAnnotation =
        (columnAnnotation?.getField('type')?.hasKnownValue ?? false);
    column = Column(
      isNullable: column.isNullable,
      length: column.length,
      indexType: column.indexType,
      // Only infer type when not set by the @Column annotation, for enums
      type: (isEnumField && hasColumnAnnotation)
          ? column.type
          : inferColumnType(field.type),
      defaultValue: column.defaultValue,
    );

    // Try to find a relationship
    var el = _findElement(field);
    //el ??= field;
    var ann = relationshipTypeChecker.firstAnnotationOf(el);

    if (ann != null) {
      var cr = ConstantReader(ann);
      var rc = ctx.buildContext.modelClassNameRecase;
      var type = cr.read('type').intValue;
      var localKey = cr.peek('localKey')?.stringValue;
      var foreignKey = cr.peek('foreignKey')?.stringValue;
      var foreignTable = cr.peek('foreignTable')?.stringValue;
      var cascadeOnDelete = cr.peek('cascadeOnDelete')?.boolValue == true;
      var through = cr.peek('through')?.typeValue;
      OrmBuildContext? foreign, throughContext;

      if (foreignTable == null) {
        // if (!isModelClass(field.type) &&
        //     !(field.type is InterfaceType &&
        //         isListOfModelType(field.type as InterfaceType))) {
        var canUse = (field.type is InterfaceType &&
                isListOfModelType(field.type as InterfaceType)) ||
            isModelClass(field.type);
        if (!canUse) {
          throw UnsupportedError(
              'Cannot apply relationship to field "${field.name}" - ${field.type} is not assignable to Model.');
        } else {
          try {
            var refType = field.type;

            if (refType is InterfaceType &&
                const TypeChecker.fromRuntime(List)
                    .isAssignableFromType(refType) &&
                refType.typeArguments.length == 1) {
              refType = refType.typeArguments[0];
            }

            var modelType = firstModelAncestor(refType) ?? refType;
            var modelTypeElement = modelType.element;

            if (modelTypeElement != null) {
              foreign = await buildOrmContext(
                  cache,
                  modelTypeElement as ClassElement,
                  ConstantReader(const TypeChecker.fromRuntime(Orm)
                      .firstAnnotationOf(modelTypeElement)),
                  buildStep,
                  resolver,
                  autoSnakeCaseNames);

              // Resolve throughType as well
              if (through != null && through is InterfaceType) {
                throughContext = await buildOrmContext(
                    cache,
                    through.element,
                    ConstantReader(const TypeChecker.fromRuntime(Serializable)
                        .firstAnnotationOf(modelTypeElement)),
                    buildStep,
                    resolver,
                    autoSnakeCaseNames);
              }

              var ormAnn = const TypeChecker.fromRuntime(Orm)
                  .firstAnnotationOf(modelTypeElement);

              if (ormAnn != null) {
                foreignTable =
                    ConstantReader(ormAnn).peek('tableName')?.stringValue;
              }

              if (foreign != null) {
                foreignTable ??= pluralize(
                    foreign.buildContext.modelClassNameRecase.snakeCase);
              }
            } else {
              log.warning('Ancestor model type for [${field.name}] is null');
            }
          } on StackOverflowError {
            throw UnsupportedError(
                'There is an infinite cycle between ${clazz.name} and ${field.type.getDisplayString()}. This triggered a stack overflow.');
          }
        }
      }

      // Fill in missing keys
      var rcc = ReCase(field.name);

      String keyName(OrmBuildContext ctx, String missing) {
        var localKeyName =
            findPrimaryFieldInList(ctx, ctx.buildContext.fields)?.name;
        // print(
        //     'Keyname for ${buildCtx.originalClassName}.${field.name} maybe = $_keyName??');
        if (localKeyName == null) {
          throw '${ctx.buildContext.originalClassName} has no defined primary key, '
              'so the relation on field ${buildCtx.originalClassName}.${field.name} must define a $missing.';
        } else {
          return localKeyName;
        }
      }

      if (type == RelationshipType.hasOne || type == RelationshipType.hasMany) {
        localKey ??=
            ctx.buildContext.resolveFieldName(keyName(ctx, 'local key'));
        // print(
        //     'Local key on ${buildCtx.originalClassName}.${field.name} defaulted to $localKey');
        foreignKey ??= '${rc.snakeCase}_$localKey';
      } else if (type == RelationshipType.belongsTo) {
        foreignKey ??=
            ctx.buildContext.resolveFieldName(keyName(foreign!, 'foreign key'));
        localKey ??= '${rcc.snakeCase}_$foreignKey';
      }

      // Figure out the join type.
      var joinType = JoinType.left;
      var joinTypeRdr = cr.peek('joinType')?.objectValue;
      if (joinTypeRdr != null) {
        // Unfortunately, the analyzer library provides little to nothing
        // in the way of reading enums from source, so here's a hack.
        var joinTypeType = (joinTypeRdr.type as InterfaceType);
        var enumFields =
            joinTypeType.element.fields.where((f) => f.isEnumConstant).toList();

        for (var i = 0; i < enumFields.length; i++) {
          if (enumFields[i].computeConstantValue() == joinTypeRdr) {
            joinType = JoinType.values[i];
            break;
          }
        }
      }

      var relation = RelationshipReader(
        type,
        localKey: localKey,
        foreignKey: foreignKey,
        foreignTable: foreignTable,
        cascadeOnDelete: cascadeOnDelete,
        through: through,
        foreign: foreign,
        throughContext: throughContext,
        joinType: joinType,
      );

      log.fine('Relation on ${buildCtx.originalClassName}.${field.name} => '
          'foreignKey=$foreignKey, localKey=$localKey');

      if (relation.type == RelationshipType.belongsTo) {
        var localKey = relation.localKey;

        if (localKey != null) {
          var name = ReCase(localKey).camelCase;
          ctx.buildContext.aliases[name] = localKey;

          if (!ctx.effectiveFields.any((f) => f.name == field.name)) {
            var foreignField = relation.findForeignField(ctx);
            var foreign = relation.throughContext ?? relation.foreign;
            var type = foreignField.type;

            if (foreign != null) {
              if (isSpecialId(foreign, foreignField)) {
                // Use integer
                type = field.type.element?.library?.typeProvider.intType
                    as DartType;

                //type = field.type.element?.context.typeProvider.intType;
              }
            }

            var rf = RelationFieldImpl(name, relation, type, field);
            ctx.effectiveFields.add(rf);
          }
        }
      }

      ctx.relations[field.name] = relation;
    } else {
      /*
      if (column.type == null) {
        throw 'Cannot infer SQL column type for field "${ctx.buildContext.originalClassName}.${field.name}" with type "${field.type.getDisplayString(withNullability: true)}".';
      }
      */

      // Expressions...
      column = Column(
        isNullable: column.isNullable,
        length: column.length,
        type: column.type,
        indexType: column.indexType,
        defaultValue: column.defaultValue,
        expression:
            ConstantReader(columnAnnotation).peek('expression')?.stringValue,
      );

      ctx.columns[field.name] = column;

      if (!ctx.effectiveFields.any((f) => f.name == field.name)) {
        ctx.effectiveFields.add(field);
      }
    }
  }

  return ctx;
}

/// Detect and return the correct column type
ColumnType inferColumnType(DartType type) {
  if (const TypeChecker.fromRuntime(String).isAssignableFromType(type)) {
    return ColumnType.varChar;
  }
  if (const TypeChecker.fromRuntime(int).isAssignableFromType(type)) {
    return ColumnType.int;
  }
  if (const TypeChecker.fromRuntime(double).isAssignableFromType(type)) {
    return ColumnType.double;
  }
  if (const TypeChecker.fromRuntime(num).isAssignableFromType(type)) {
    return ColumnType.float;
  }
  if (const TypeChecker.fromRuntime(bool).isAssignableFromType(type)) {
    return ColumnType.boolean;
  }
  if (const TypeChecker.fromRuntime(DateTime).isAssignableFromType(type)) {
    return ColumnType.timeStamp;
  }
  if (const TypeChecker.fromRuntime(Map).isAssignableFromType(type)) {
    return ColumnType.jsonb;
  }
  if (const TypeChecker.fromRuntime(List).isAssignableFromType(type)) {
    return ColumnType.jsonb;
  }
  if (type is InterfaceType && type.element is EnumElement) {
    return ColumnType.int;
  }

  // Default to varChar
  return ColumnType.varChar;
}

Column reviveColumn(ConstantReader cr) {
  ColumnType columnType;

  var indexTypeObj = cr.peek('indexType')?.objectValue;
  indexTypeObj ??= cr.revive().namedArguments['indexType'];

  var columnObj =
      cr.peek('type')?.objectValue.getField('name')?.toStringValue();
  var indexType = IndexType.values[
      indexTypeObj?.getField('index')?.toIntValue() ?? IndexType.none.index];

  if (const TypeChecker.fromRuntime(PrimaryKey)
      .isAssignableFromType(cr.objectValue.type!)) {
    indexType = IndexType.primaryKey;
  }

  if (columnObj != null) {
    columnType = _ColumnType(columnObj);
  } else {
    // Default to varchar
    columnType = ColumnType.varChar;
  }

  return Column(
    isNullable: cr.peek('isNullable')?.boolValue ?? false,
    length: cr.peek('length')?.intValue ?? 255,
    defaultValue: cr.peek('defaultValue')?.objectValue,
    type: columnType,
    indexType: indexType,
  );
}

const TypeChecker relationshipTypeChecker =
    TypeChecker.fromRuntime(Relationship);

// ORM builder context
class OrmBuildContext {
  final BuildContext buildContext;
  final Orm ormAnnotation;
  final String? tableName;

  final Map<String, Column> columns = {};
  final List<FieldElement> effectiveFields = [];
  final Map<String, RelationshipReader> relations = {};

  OrmBuildContext(this.buildContext, this.ormAnnotation, this.tableName);

  bool isNotCustomExprField(FieldElement field) {
    var col = columns[field.name];
    return col?.hasExpression != true;
  }

  Iterable<FieldElement> get effectiveNormalFields =>
      effectiveFields.where(isNotCustomExprField);
}

class _ColumnType implements ColumnType {
  @override
  final String name;

  @override
  bool hasLength = false;

  @override
  bool hasPrecision = false;

  @override
  bool hasScale = false;

  @override
  bool hasTimezone = false;

  //_ColumnType(this.name, [this.hasSize = false]);
  _ColumnType(this.name);
}

class RelationFieldImpl extends ShimFieldImpl {
  final FieldElement originalField;
  final RelationshipReader relationship;
  RelationFieldImpl(
      String name, this.relationship, DartType type, this.originalField)
      : super(name, type);

  String get originalFieldName => originalField.name;

  //@override
  //PropertyAccessorElement? get getter => originalField.getter;
}

InterfaceType? firstModelAncestor(DartType? type) {
  if (type is InterfaceType) {
    if (type.superclass != null &&
        const TypeChecker.fromRuntime(Model).isExactlyType(type.superclass!)) {
      return type;
    } else {
      return type.superclass == null
          ? null
          : firstModelAncestor(type.superclass);
    }
  } else {
    return null;
  }
}
