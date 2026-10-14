import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

import 'package:analyzer/dart/element/type.dart';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:build/build.dart';
import 'package:inflection3/inflection3.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'readers.dart';

bool isHasRelation(Relationship r) =>
    r.type == RelationshipType.hasOne || r.type == RelationshipType.hasMany;

bool isSpecialId(OrmBuildContext ctx, OrmField field) {
  return field is ClassOrmField &&
      field.displayName == 'id' &&
      const TypeChecker.typeNamed(Model)
          .isAssignableFromType(ctx.buildContext.clazz.thisType);
}

/// The element whose annotations describe [field].
Element _findElement(FieldElement field) {
  return (field.setter == null ? field.getter : field) ?? field;
}

OrmField? findPrimaryFieldInList(
  OrmBuildContext ctx,
  Iterable<OrmField> fields,
) {
  for (var field in fields) {
    // A relation's column has no annotations of its own.
    if (field is! ClassOrmField) continue;
    var element = _findElement(field.element);
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
  bool? autoSnakeCaseNames, {
  bool heedExclude = true,
}) async {
  // Check for @generatedSerializable
  // ignore: unused_local_variable
  DartObject? generatedSerializable;

  while ((generatedSerializable = const TypeChecker.typeNamed(
        GeneratedSerializable,
      ).firstAnnotationOf(clazz)) !=
      null) {
    if (clazz.supertype != null) {
      clazz = clazz.supertype!.element;
    }
  }

  //var id = clazz.location?.components.join('-') ?? '';
  var id = "${clazz.library.baseElement}-${clazz.displayName}";
  if (cache.containsKey(id)) {
    return cache[id];
  }
  var buildCtx = await buildContext(
    clazz,
    annotation,
    buildStep,
    resolver,
    autoSnakeCaseNames!,
    heedExclude: heedExclude,
  );
  var ormAnnotation = reviveORMAnnotation(annotation);
  //print(
  //     'tableName (${annotation.objectValue.type?.getDisplayString() ?? ''}) => ${ormAnnotation.tableName} from ${clazz.name} (${annotation.revive().namedArguments})');
  if (buildCtx == null) {
    log.severe('BuildContext is null');

    return null;
  }

  // TODO: ORM Context Builder
  var ctx = OrmBuildContext(
    buildCtx,
    ormAnnotation,
    (ormAnnotation.tableName?.isNotEmpty == true)
        ? ormAnnotation.tableName!
        : pluralize(
            ReCase(getGeneratedModelClassName(clazz.displayName)).snakeCase,
          ),
  );
  cache[id] = ctx;

  // Read all fields
  for (var classField in buildCtx.fields) {
    var field = ClassOrmField(classField);
    // Check for column annotation...
    var element = _findElement(classField);
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
        type: ColumnType.serial,
        indexType: IndexType.primaryKey,
      );
    }

    column ??= Column(
      type: inferColumnType(
        buildCtx.resolveSerializedFieldType(field.displayName),
      ),
    );
    column = Column(
      isNullable: column.isNullable,
      length: column.length,
      precision: column.precision,
      scale: column.scale,
      indexType: column.indexType,
      // The type the annotation declares, if any; otherwise inferred.
      type: columnAnnotation != null &&
              declaresColumnType(ConstantReader(columnAnnotation))
          ? column.type
          : inferColumnType(field.type),
      defaultValue: column.defaultValue,
    );

    // Try to find a relationship
    var ann = relationshipTypeChecker.firstAnnotationOf(element);

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

      var canUse =
          (field.type is InterfaceType &&
              isListOfModelType(field.type as InterfaceType)) ||
          isModelClass(field.type);
      if (!canUse) {
        // Even with a foreignTable, the related model is needed for its
        // columns and keys.
        throw UnsupportedError(
          'Cannot apply relationship to field "${field.displayName}" - ${field.type} is not assignable to Model.',
        );
      } else {
          try {
            var refType = field.type;

            if (refType is InterfaceType &&
                const TypeChecker.typeNamed(List)
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
                ConstantReader(
                  const TypeChecker.typeNamed(Orm)
                      .firstAnnotationOf(modelTypeElement),
                ),
                buildStep,
                resolver,
                autoSnakeCaseNames,
              );

              // Resolve throughType as well
              if (through != null && through is InterfaceType) {
                throughContext = await buildOrmContext(
                  cache,
                  through.element,
                  ConstantReader(
                    const TypeChecker.typeNamed(Orm)
                        .firstAnnotationOf(through.element),
                  ),
                  buildStep,
                  resolver,
                  autoSnakeCaseNames,
                );
              }

              var ormAnn = const TypeChecker.typeNamed(Orm)
                  .firstAnnotationOf(modelTypeElement);

              // An explicit foreignTable wins over the model's own.
              if (ormAnn != null) {
                foreignTable ??= ConstantReader(ormAnn)
                    .peek('tableName')
                    ?.stringValue;
              }

              if (foreign != null) {
                foreignTable ??= pluralize(
                  foreign.buildContext.modelClassNameRecase.snakeCase,
                );
              }
            } else {
              log.warning(
                'Ancestor model type for [${field.displayName}] is null',
              );
            }
          } on StackOverflowError {
            throw UnsupportedError(
              'There is an infinite cycle between ${clazz.displayName} and ${field.type.getDisplayString()}. This triggered a stack overflow.',
            );
          }
      }

      // Fill in missing keys
      var rcc = ReCase(field.displayName);

      String keyName(OrmBuildContext ctx, String missing) {
        var localKeyName = findPrimaryFieldInList(
          ctx,
          ctx.buildContext.fields.map(ClassOrmField.new),
        )?.displayName;
        // print(
        //     'Keyname for ${buildCtx.originalClassName}.${field.name} maybe = $_keyName??');
        if (localKeyName == null) {
          throw '${ctx.buildContext.originalClassName} has no defined primary key, '
              'so the relation on field ${buildCtx.originalClassName}.${field.displayName} must define a $missing.';
        } else {
          return localKeyName;
        }
      }

      if (type == RelationshipType.hasOne || type == RelationshipType.hasMany) {
        localKey ??= ctx.buildContext.resolveFieldName(
          keyName(ctx, 'local key'),
        );
        // print(
        //     'Local key on ${buildCtx.originalClassName}.${field.name} defaulted to $localKey');
        foreignKey ??= '${rc.snakeCase}_$localKey';
      } else if (type == RelationshipType.belongsTo) {
        foreignKey ??= ctx.buildContext.resolveFieldName(
          keyName(foreign!, 'foreign key'),
        );
        localKey ??= '${rcc.snakeCase}_$foreignKey';
      }

      // Figure out the join type.
      var joinType = JoinType.left;
      var joinTypeRdr = cr.peek('joinType')?.objectValue;
      if (joinTypeRdr != null) {
        // Unfortunately, the analyzer library provides little to nothing
        // in the way of reading enums from source, so here's a hack.
        var joinTypeType = (joinTypeRdr.type as InterfaceType);
        var enumFields = joinTypeType.element.fields
            .where((f) => f.isEnumConstant)
            .toList();

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

      log.fine(
        'Relation on ${buildCtx.originalClassName}.${field.displayName} => '
        'foreignKey=$foreignKey, localKey=$localKey',
      );

      if (relation.type == RelationshipType.belongsTo) {
        var localKey = relation.localKey;

        if (localKey != null) {
          var name = ReCase(localKey).camelCase;
          ctx.buildContext.aliases[name] = localKey;

          if (!ctx.effectiveFields.any(
            (f) => f.displayName == field.displayName,
          )) {
            var foreignField = relation.findForeignField(ctx);
            var foreign = relation.throughContext ?? relation.foreign;
            var type = foreignField.type;

            if (foreign != null) {
              if (isSpecialId(foreign, foreignField)) {
                // Use integer
                type =
                    field.type.element?.library?.typeProvider.intType
                        as DartType;

                //type = field.type.element?.context.typeProvider.intType;
              }
            }

            ctx.effectiveFields.add(
              RelationFieldImpl(name, relation, type, classField),
            );
          }
        }
      }

      ctx.relations[field.displayName] = relation;
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
        precision: column.precision,
        scale: column.scale,
        type: column.type,
        indexType: column.indexType,
        defaultValue: column.defaultValue,
        expression: ConstantReader(columnAnnotation)
            .peek('expression')
            ?.stringValue,
      );

      ctx.columns[field.displayName] = column;

      if (!ctx.effectiveFields.any((f) => f.displayName == field.displayName)) {
        ctx.effectiveFields.add(field);
      }
    }
  }

  return ctx;
}

/// Whether a `@Column` (or `@PrimaryKey`) annotation passes a column type
/// itself: `Column`'s `type` always has a value, `ColumnType.varChar` when it
/// is not given.
bool declaresColumnType(ConstantReader annotation) {
  var arguments = annotation.revive().namedArguments;
  return arguments.containsKey('type') || arguments.containsKey('columnType');
}

/// Detect and return the correct column type
ColumnType inferColumnType(DartType type) {
  if (const TypeChecker.typeNamed(String).isAssignableFromType(type)) {
    return ColumnType.varChar;
  }
  if (const TypeChecker.typeNamed(int).isAssignableFromType(type)) {
    return ColumnType.int;
  }
  if (const TypeChecker.typeNamed(double).isAssignableFromType(type)) {
    return ColumnType.double;
  }
  if (const TypeChecker.typeNamed(num).isAssignableFromType(type)) {
    return ColumnType.float;
  }
  if (const TypeChecker.typeNamed(bool).isAssignableFromType(type)) {
    return ColumnType.boolean;
  }
  if (const TypeChecker.typeNamed(DateTime).isAssignableFromType(type)) {
    return ColumnType.timeStamp;
  }
  if (const TypeChecker.typeNamed(Map).isAssignableFromType(type)) {
    return ColumnType.jsonb;
  }
  if (const TypeChecker.typeNamed(List).isAssignableFromType(type)) {
    return ColumnType.jsonb;
  }
  if (type is InterfaceType && type.element is EnumElement) {
    return ColumnType.int;
  }

  // Default to varChar
  return ColumnType.varChar;
}

/// The column types `ColumnType` defines, by the name of their constant.
const Map<String, ColumnType> _knownColumnTypes = {
  'boolean': ColumnType.boolean,
  'smallSerial': ColumnType.smallSerial,
  'serial': ColumnType.serial,
  'bigSerial': ColumnType.bigSerial,
  'bigInt': ColumnType.bigInt,
  'int': ColumnType.int,
  'smallInt': ColumnType.smallInt,
  'tinyInt': ColumnType.tinyInt,
  'bit': ColumnType.bit,
  'decimal': ColumnType.decimal,
  'numeric': ColumnType.numeric,
  'money': ColumnType.money,
  'smallMoney': ColumnType.smallMoney,
  'float': ColumnType.float,
  'real': ColumnType.real,
  'double': ColumnType.double,
  'dateTime': ColumnType.dateTime,
  'smallDateTime': ColumnType.smallDateTime,
  'date': ColumnType.date,
  'time': ColumnType.time,
  'timeStamp': ColumnType.timeStamp,
  'timeStampWithTimeZone': ColumnType.timeStampWithTimeZone,
  'char': ColumnType.char,
  'varChar': ColumnType.varChar,
  'varCharMax': ColumnType.varCharMax,
  'text': ColumnType.text,
  'nChar': ColumnType.nChar,
  'nVarChar': ColumnType.nVarChar,
  'nVarCharMax': ColumnType.nVarCharMax,
  'nText': ColumnType.nText,
  'binary': ColumnType.binary,
  'varBinary': ColumnType.varBinary,
  'varBinaryMax': ColumnType.varBinaryMax,
  'image': ColumnType.image,
  'json': ColumnType.json,
  'jsonb': ColumnType.jsonb,
  'sqlVariant': ColumnType.sqlVariant,
  'uniqueIdentifier': ColumnType.uniqueIdentifier,
  'xml': ColumnType.xml,
  'cursor': ColumnType.cursor,
  'table': ColumnType.table,
};

/// The name of the `ColumnType` constant that [type] is, or null when it is
/// not one of them.
String? columnTypeConstantName(ColumnType type) {
  for (var entry in _knownColumnTypes.entries) {
    if (identical(entry.value, type)) return entry.key;
  }
  return null;
}

Column reviveColumn(ConstantReader cr) {
  ColumnType columnType;

  var indexTypeObj = cr.peek('indexType')?.objectValue;
  indexTypeObj ??= cr.revive().namedArguments['indexType'];

  var columnObj = cr
      .peek('type')
      ?.objectValue
      .getField('name')
      ?.toStringValue();
  var indexType =
      IndexType.values[indexTypeObj?.getField('index')?.toIntValue() ??
          IndexType.none.index];

  if (const TypeChecker.typeNamed(PrimaryKey)
      .isAssignableFromType(cr.objectValue.type!)) {
    indexType = IndexType.primaryKey;
  }

  if (columnObj != null) {
    // The ColumnType constant of that name, which the generator compares
    // types with; ColumnType has no `==` of its own.
    columnType = _knownColumnTypes.values.firstWhere(
      (t) => t.name == columnObj,
      orElse: () => _ColumnType(columnObj),
    );
  } else {
    // Default to varchar
    columnType = ColumnType.varChar;
  }

  return Column(
    isNullable: cr.peek('isNullable')?.boolValue ?? false,
    length: cr.peek('length')?.intValue ?? 255,
    precision: cr.peek('precision')?.intValue ?? 17,
    scale: cr.peek('scale')?.intValue ?? 3,
    defaultValue: cr.peek('defaultValue')?.objectValue,
    type: columnType,
    indexType: indexType,
  );
}

const TypeChecker relationshipTypeChecker = TypeChecker.typeNamed(Relationship);

// ORM builder context
class OrmBuildContext {
  final BuildContext buildContext;
  final Orm ormAnnotation;
  final String tableName;

  final Map<String, Column> columns = {};

  /// The columns of the model: its fields, and those its relations add
  /// (e.g. `authorId` for a `@BelongsTo Author author`).
  final List<OrmField> effectiveFields = [];
  final Map<String, RelationshipReader> relations = {};

  OrmBuildContext(this.buildContext, this.ormAnnotation, this.tableName);

  bool isNotCustomExprField(OrmField field) {
    var col = columns[field.displayName];
    return col?.hasExpression != true;
  }

  Iterable<OrmField> get effectiveNormalFields =>
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

/// A column of an ORM model: a field of its class ([ClassOrmField]), or one
/// that a relation adds ([RelationFieldImpl]).
sealed class OrmField {
  const OrmField();

  /// The name of the field in the generated code.
  String get name;

  String get displayName => name;

  DartType get type;
}

/// A field of the model's class.
class ClassOrmField extends OrmField {
  final FieldElement element;

  const ClassOrmField(this.element);

  @override
  String get name => element.name!;

  @override
  String get displayName => element.displayName;

  @override
  DartType get type => element.type;
}

/// The column a relation adds to its model, such as `authorId` for a
/// `@BelongsTo Author author`. It has no element of its own.
class RelationFieldImpl extends OrmField {
  final String fieldName;
  @override
  final DartType type;
  final FieldElement originalField;
  final RelationshipReader relationship;

  const RelationFieldImpl(
    this.fieldName,
    this.relationship,
    this.type,
    this.originalField,
  );

  @override
  String get name => fieldName;

  String get originalFieldName => originalField.displayName;
}

InterfaceType? firstModelAncestor(DartType? type) {
  if (type is InterfaceType) {
    if (type.superclass != null &&
        const TypeChecker.typeNamed(Model).isExactlyType(type.superclass!)) {
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
