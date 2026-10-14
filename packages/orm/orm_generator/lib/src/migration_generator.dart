import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_model/angel3_model.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart' hide LibraryBuilder;

import 'orm_build_context.dart';

/// Migration Builder
Builder migrationBuilder(BuilderOptions options) {
  return SharedPartBuilder([
    MigrationGenerator(
      autoSnakeCaseNames: options.config['auto_snake_case_names'] != false,
    ),
  ], 'angel3_migration');
}

/// Generates `<Model>Migration.dart` from an abstract `Model` class.
class MigrationGenerator extends GeneratorForAnnotation<Orm> {
  final _logger = Logger('MigrationGenerator');

  static final Parameter _schemaParam = Parameter(
    (b) => b
      ..name = 'schema'
      ..type = refer('Schema'),
  );
  static final Reference _schema = refer('schema');

  /// If `true` (default), then field names will automatically be (de)serialized as snake_case.
  final bool autoSnakeCaseNames;

  MigrationGenerator({this.autoSnakeCaseNames = true});

  @override
  Future<String?> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw 'Only classes can be annotated with @ORM().';
    }

    var generateMigrations =
        annotation.peek('generateMigrations')?.boolValue ?? true;

    if (!generateMigrations) {
      return null;
    }

    var resolver = buildStep.resolver;
    var ctx = await buildOrmContext(
      {},
      element,
      annotation,
      buildStep,
      resolver,
      autoSnakeCaseNames != false,
    );

    if (ctx == null) {
      throw 'Invalid ORM build context';
    }

    // Create `FooMigration` class
    var lib = generateMigrationLibrary(ctx, element, resolver, buildStep);

    //if (lib == null) return null;
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(lib.accept(DartEmitter(useNullSafetySyntax: true)).toString());
  }

  Library generateMigrationLibrary(
    OrmBuildContext ctx,
    ClassElement element,
    Resolver resolver,
    BuildStep buildStep,
  ) {
    return Library((lib) {
      lib.body.add(
        Class((clazz) {
          clazz
            ..name = '${ctx.buildContext.modelClassName}Migration'
            ..extend = refer('Migration')
            ..methods.addAll([
              buildUpMigration(ctx, lib),
              buildDownMigration(ctx),
            ]);
        }),
      );
    });
  }

  /// Generate up() method to create tables
  Method buildUpMigration(OrmBuildContext ctx, LibraryBuilder lib) {
    return Method((meth) {
      // Check to see if clazz extends Model class

      var autoIdAndDateFields = const TypeChecker.typeNamed(Model)
          .isAssignableFromType(ctx.buildContext.clazz.thisType);
      meth
        ..name = 'up'
        ..returns = refer('void')
        ..annotations.add(refer('override'))
        ..requiredParameters.add(_schemaParam);

      //var closure = Method.closure()..addPositional(parameter('table'));
      var closure = Method((closure) {
        closure
          ..requiredParameters.add(Parameter((b) => b..name = 'table'))
          ..body = Block((closureBody) {
            var table = refer('table');

            var dup = <String>[];
            ctx.columns.forEach((name, col) {
              // Skip custom-expression columns.
              if (col.hasExpression) return;

              var key = ctx.buildContext.resolveFieldName(name);

              if (dup.contains(key)) {
                return;
              } else {
                // if (key != 'id' || autoIdAndDateFields == false) {
                //   // Check for relationships that might duplicate
                //   for (var rName in ctx.relations.keys) {
                //     var relationship = ctx.relations[rName];
                //     if (relationship.localKey == key) return;
                //   }
                // }

                // Fix from: https://github.com/angel-dart/angel/issues/114#issuecomment-505525729
                if (!(col.indexType == IndexType.primaryKey ||
                    (autoIdAndDateFields != false && name == 'id'))) {
                  // Check for relationships that might duplicate
                  for (var rName in ctx.relations.keys) {
                    var relationship = ctx.relations[rName]!;
                    if (relationship.localKey == key) return;
                  }
                }
                if (key != null) {
                  dup.add(key);
                } else {
                  _logger.fine('Skip: key is null');
                }
              }

              String? methodName;
              var positional = <Expression>[literal(key)];
              var named = <String, Expression>{};

              if (autoIdAndDateFields != false && name == 'id') {
                methodName = 'serial';
              }

              if (methodName == null) {
                switch (col.type) {
                  case ColumnType.varChar:
                    methodName = 'varChar';
                    if (col.type.hasLength) {
                      named['length'] = literal(col.length);
                    }
                    break;
                  case ColumnType.serial:
                    methodName = 'serial';
                    break;
                  case ColumnType.int:
                    methodName = 'integer';
                    break;
                  case ColumnType.float:
                    methodName = 'float';
                    break;
                  case ColumnType.double:
                    methodName = 'double';
                    break;
                  case ColumnType.numeric:
                    methodName = 'numeric';
                    named['precision'] = literal(col.precision);
                    named['scale'] = literal(col.scale);
                    break;
                  case ColumnType.boolean:
                    methodName = 'boolean';
                    break;
                  case ColumnType.date:
                    methodName = 'date';
                    break;
                  case ColumnType.dateTime:
                    methodName = 'dateTime';
                    break;
                  case ColumnType.timeStamp:
                    methodName = 'timeStamp';
                    break;
                  default:
                    var type = col.type;
                    var typeExpr = _columnTypeExpression(type);
                    var hasLength = type.hasLength && col.length != 0;

                    if (hasLength || type.hasPrecision || type.hasScale) {
                      methodName = 'declareColumn';
                      positional.add(
                        refer('Column').newInstance([], {
                          'type': typeExpr,
                          if (hasLength) 'length': literal(col.length),
                          if (type.hasPrecision)
                            'precision': literal(col.precision),
                          if (type.hasScale) 'scale': literal(col.scale),
                        }),
                      );
                    } else {
                      methodName = 'declare';
                      positional.add(typeExpr);
                    }
                    break;
                }
              }

              var field = table.property(methodName).call(positional, named);

              var cascade = <Expression>[];

              var defaultValue = ctx.buildContext.defaults[name];

              // Handle 'defaultValue' on Column annotation
              if (col.defaultValue != null) {
                var defaultCode = dartObjectToString(
                  col.defaultValue as DartObject,
                );

                if (defaultCode != null) {
                  Expression defaultExpr = CodeExpression(Code(defaultCode));
                  cascade.add(refer('defaultsTo').call([defaultExpr]));
                }

                // Handle 'defaultValue' on SerializableField annotation
              } else if (defaultValue != null && !defaultValue.isNull) {
                var type = defaultValue.type;
                Expression? defaultExpr;

                if (const TypeChecker.typeNamed(RawSql)
                    .isAssignableFromType(defaultValue.type!)) {
                  var value = ConstantReader(defaultValue)
                      .read('value')
                      .stringValue;
                  defaultExpr = refer('RawSql')
                      .constInstance([literalString(value)]);
                } else if (type is InterfaceType &&
                    type.element is EnumElement) {
                  // Default to enum index.
                  try {
                    var index = ConstantReader(defaultValue)
                        .read('index')
                        .intValue;
                    defaultExpr = literalNum(index);
                  } catch (error) {
                    _logger.warning(error);
                    // Extremely weird error occurs here: `Not an instance of int`.
                    // Definitely an analyzer issue.
                  }
                } else {
                  var defaultCode = dartObjectToString(defaultValue);
                  if (defaultCode != null) {
                    defaultExpr = CodeExpression(Code(defaultCode));
                  }
                }

                if (defaultExpr != null) {
                  cascade.add(refer('defaultsTo').call([defaultExpr]));
                }
              }

              if (col.indexType == IndexType.primaryKey ||
                  (autoIdAndDateFields != false && name == 'id')) {
                cascade.add(refer('primaryKey').call([]));
              } else if (col.indexType == IndexType.unique) {
                cascade.add(refer('unique').call([]));
              }

              if (!col.isNullable) {
                cascade.add(refer('notNull').call([]));
              }

              if (cascade.isNotEmpty) {
                var b = StringBuffer()
                  ..writeln(
                    field.accept(DartEmitter(useNullSafetySyntax: true)),
                  );

                if (cascade.length == 1) {
                  var ex = cascade[0];
                  b
                    ..write('.')
                    ..writeln(
                      ex.accept(DartEmitter(useNullSafetySyntax: true)),
                    );
                } else {
                  for (var ex in cascade) {
                    b
                      ..write('..')
                      ..writeln(
                        ex.accept(DartEmitter(useNullSafetySyntax: true)),
                      );
                  }
                }

                field = CodeExpression(Code(b.toString()));
              }

              closureBody.addExpression(field);
            });

            ctx.relations.forEach((name, r) {
              var relationship = r;

              if (relationship.type == RelationshipType.belongsTo) {
                // Fix from https://github.com/angel-dart/angel/issues/116#issuecomment-505546479
                // var key = relationship.localKey;

                // var field = table.property('integer').call([literal(key)]);
                // // .references('user', 'id').onDeleteCascade()

                // Check to see if foreign clazz extends Model class
                var foreignTableType =
                    relationship.foreign?.buildContext.clazz.thisType;
                var foreignAautoIdAndDateFields = false;
                if (foreignTableType != null) {
                  foreignAautoIdAndDateFields = const TypeChecker.typeNamed(
                    Model,
                  ).isAssignableFromType(foreignTableType);
                }

                var key = relationship.localKey;

                // Default to `int` if foreign class extends Model with implicit 'id'
                // as primary key
                ColumnType keyType;
                if (foreignAautoIdAndDateFields != false &&
                    relationship.foreignKey == "id") {
                  keyType = ColumnType.int;
                } else {
                  var foreignColumn =
                      relationship.foreign?.columns[relationship.foreignKey!];
                  keyType = _foreignKeyType(foreignColumn?.type);
                }

                var field = table.property('declare').call([
                  literal(key),
                  _columnTypeExpression(keyType),
                ]);

                var ref = field.property('references').call([
                  literal(relationship.foreignTable),
                  literal(relationship.foreignKey),
                ]);

                if (relationship.cascadeOnDelete != false &&
                    const [
                      RelationshipType.hasOne,
                      RelationshipType.belongsTo,
                    ].contains(relationship.type)) {
                  ref = ref.property('onDeleteCascade').call([]);
                }
                closureBody.addExpression(ref);
              }
            });
          });
      });

      meth.body = Block((b) {
        b.addExpression(
          _schema.property('create').call([
            literal(ctx.tableName),
            closure.closure,
          ]),
        );
      });
    });
  }

  /// The `ColumnType` constant for [type], or a new `ColumnType` when it is
  /// not one of them. Runners compare column types by identity, so known
  /// types must stay the constants.
  Expression _columnTypeExpression(ColumnType type) {
    var constName = columnTypeConstantName(type);
    if (constName != null) {
      return refer('ColumnType').property(constName);
    }

    return refer('ColumnType').constInstance([literal(type.name)], {
      if (type.hasLength) 'hasLength': literal(true),
      if (type.hasPrecision) 'hasPrecision': literal(true),
      if (type.hasScale) 'hasScale': literal(true),
    });
  }

  /// The column type of a foreign key that references a column of [type]:
  /// serial types become the integer type they auto-increment.
  ColumnType _foreignKeyType(ColumnType? type) {
    if (type == null) return ColumnType.int;
    if (identical(type, ColumnType.serial)) return ColumnType.int;
    if (identical(type, ColumnType.bigSerial)) return ColumnType.bigInt;
    if (identical(type, ColumnType.smallSerial)) return ColumnType.smallInt;
    return type;
  }

  /// Generate down() method to drop tables
  Method buildDownMigration(OrmBuildContext? ctx) {
    return Method((b) {
      b
        ..name = 'down'
        ..returns = refer('void')
        ..annotations.add(refer('override'))
        ..requiredParameters.add(_schemaParam)
        ..body = Block((b) {
          var named = <String, Expression>{};

          if (ctx!.relations.values.any(
            (r) =>
                r.type == RelationshipType.hasOne ||
                r.type == RelationshipType.hasMany ||
                r.isManyToMany,
          )) {
            named['cascade'] = literalTrue;
          }

          b.addExpression(
            _schema.property('drop').call([
              literalString(ctx.tableName),
            ], named),
          );
        });
    });
  }
}
