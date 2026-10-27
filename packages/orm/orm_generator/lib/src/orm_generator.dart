import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' hide LibraryBuilder;
import 'package:source_gen/source_gen.dart';

import 'orm_build_context.dart';
import 'readers.dart';

var floatTypes = [
  ColumnType.decimal,
  ColumnType.float,
  ColumnType.numeric,
  ColumnType.real,
  const ColumnType('double precision'),
];

/// ORM Builder
Builder ormBuilder(BuilderOptions options) {
  return SharedPartBuilder([
    OrmGenerator(
      autoSnakeCaseNames: options.config['auto_snake_case_names'] != false,
    ),
  ], 'angel3_orm');
}

TypeReference futureOf(String type) {
  return TypeReference(
    (b) => b
      ..symbol = 'Future'
      ..types.add(refer(type)),
  );
}

/// Generate `<Model>.g.dart` from an abstract `Model` class.
class OrmGenerator extends GeneratorForAnnotation<Orm> {
  final bool? autoSnakeCaseNames;

  OrmGenerator({this.autoSnakeCaseNames});

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is ClassElement) {
      var ctx = await buildOrmContext(
        {},
        element,
        annotation,
        buildStep,
        buildStep.resolver,
        autoSnakeCaseNames,
      );
      if (ctx == null) {
        throw 'Invalid ORM build context';
      }

      var lib = buildOrmLibrary(buildStep.inputId, ctx);

      return lib.accept(DartEmitter(useNullSafetySyntax: true)).toString();
    } else {
      throw 'The @Orm() annotation can only be applied to classes.';
    }
  }

  Library buildOrmLibrary(AssetId inputId, OrmBuildContext ctx) {
    return Library((lib) {
      // Create `FooQuery` class
      lib.body.add(buildQueryClass(ctx));

      // Create `FooQueryWhere` class
      lib.body.add(buildWhereClass(ctx));

      // Create `FooQueryValues` class
      lib.body.add(buildValuesClass(ctx));
    });
  }

  /// Generate "Model"Query class
  Class buildQueryClass(OrmBuildContext ctx) {
    return Class((clazz) {
      var rc = ctx.buildContext.modelClassNameRecase;

      var queryWhereType = refer('${rc.pascalCase}QueryWhere');

      log.info('Generating ${rc.pascalCase}QueryWhere');

      var nullableQueryWhereType = TypeReference(
        (b) => b
          ..symbol = '${rc.pascalCase}QueryWhere'
          ..isNullable = true,
      );

      clazz
        ..name = '${rc.pascalCase}Query'
        ..extend = TypeReference((b) {
          b
            ..symbol = 'Query'
            ..types.addAll([ctx.buildContext.modelClassType, queryWhereType]);
        });

      // Override casts so that we can cast doubles
      clazz.methods.add(
        Method((b) {
          b
            ..name = 'casts'
            ..annotations.add(refer('override'))
            ..returns = TypeReference(
              (b) => b
                ..symbol = 'Map'
                ..types.add(refer('String'))
                ..types.add(refer('String')),
            )
            ..type = MethodType.getter
            ..body = Block((b) {
              var args = <String, Expression>{};

              /* Remove casts no numeric values
            for (var field in ctx.effectiveFields) {
              var name = ctx.buildContext.resolveFieldName(field.name);
              var type = ctx.columns[field.name]?.type;
              if (type == null) continue;
              if (floatTypes.contains(type)) {
                //args[name] = literalString('text');
                args[name!] = literalString('char');
              }
            }
            */

              b.addExpression(literalMap(args).returned);
            });
        }),
      );

      // Add values
      clazz.fields.add(
        Field((b) {
          var type = refer('${rc.pascalCase}QueryValues');
          b
            ..name = 'values'
            ..modifier = FieldModifier.final$
            ..annotations.add(refer('override'))
            ..type = type
            ..assignment = type.newInstance([]).code;
        }),
      );

      // Add tableName
      clazz.methods.add(
        Method((m) {
          m
            ..name = 'tableName'
            ..returns = refer('String')
            ..annotations.add(refer('override'))
            ..type = MethodType.getter
            ..body = Block((b) {
              b.addExpression(literalString(ctx.tableName).returned);
            });
        }),
      );

      // Add fields getter
      clazz.methods.add(
        Method((m) {
          //log.fine('Field: $name');
          m
            ..name = 'fields'
            ..returns = TypeReference(
              (b) => b
                ..symbol = 'List'
                ..types.add(TypeReference((b) => b..symbol = 'String')),
            )
            ..annotations.add(refer('override'))
            ..type = MethodType.getter
            ..body = Block((b) {
              var names = ctx.effectiveFields
                  .map(
                    (f) => literalString(
                      ctx.buildContext.resolveFieldName(f.displayName)!,
                    ),
                  )
                  .toList();
              b.addExpression(
                declareConst('localFields').assign(literalConstList(names)),
              );
              b.addExpression(
                refer('_selectedFields')
                    .property('isEmpty')
                    .conditional(
                      refer('localFields'),
                      refer('localFields')
                          .property('where')
                          .call([
                            CodeExpression(
                              Code(
                                '(field) => _selectedFields.contains(field)',
                              ),
                            ),
                          ])
                          .property('toList')
                          .call([]),
                    )
                    .returned,
              );
            });
        }),
      );

      // Add _selectedFields member
      clazz.fields.add(
        Field((b) {
          b
            ..name = '_selectedFields'
            ..type = TypeReference(
              (t) => t
                ..symbol = 'List'
                ..types.add(TypeReference((b) => b..symbol = 'String')),
            )
            ..assignment = Code('[]');
        }),
      );

      // Add select(List<String> fields)
      clazz.methods.add(
        Method((m) {
          m
            ..name = 'select'
            ..returns = refer('${rc.pascalCase}Query')
            ..requiredParameters.add(
              Parameter(
                (b) => b
                  ..name = 'selectedFields'
                  ..type = TypeReference(
                    (t) => t
                      ..symbol = 'List'
                      ..types.add(TypeReference((b) => b..symbol = 'String')),
                  ),
              ),
            )
            ..body = Block((b) {
              b.addExpression(
                refer('_selectedFields').assign(refer('selectedFields')),
              );
              b.addExpression(refer('this').returned);
            });
        }),
      );

      // Add _where member
      clazz.fields.add(
        Field((b) {
          b
            ..name = '_where'
            ..type = nullableQueryWhereType;
        }),
      );

      // Add where getter
      clazz.methods.add(
        Method((b) {
          b
            ..name = 'where'
            ..type = MethodType.getter
            ..returns = nullableQueryWhereType
            ..annotations.add(refer('override'))
            ..body = Block((b) => b.addExpression(refer('_where').returned));
        }),
      );

      // newWhereClause()
      clazz.methods.add(
        Method((b) {
          b
            ..name = 'newWhereClause'
            ..annotations.add(refer('override'))
            ..returns = queryWhereType
            ..body = Block(
              (b) => b.addExpression(
                queryWhereType.newInstance([refer('this')]).returned,
              ),
            );
        }),
      );

      // Add parseRow()
      clazz.methods.add(
        Method((m) {
          m
            ..name = 'parseRow'
            ..returns = refer('Optional<${rc.pascalCase}>')
            ..requiredParameters.add(
              Parameter(
                (b) => b
                  ..name = 'row'
                  ..type = refer('List'),
              ),
            )
            ..body = Block((b) {
              // Build the arguments for model
              var args = <String, Expression>{};
              for (var field in ctx.effectiveFields) {
                var fieldName = field.displayName;

                var fType = field.type;

                Reference type = convertTypeReference(fType);
                if (isSpecialId(ctx, field)) {
                  type = refer('int');
                }

                // Generated Code: row[fields.indexOf('column')], as fields
                // may be a selection of them, in the order of the SELECT.
                var expr = refer('row').index(
                  refer('fields').property('indexOf').call([
                    literalString(
                      ctx.buildContext.resolveFieldName(fieldName) ?? fieldName,
                    ),
                  ]),
                );
                if (isSpecialId(ctx, field)) {
                  // Generated Code: row[i].toString()

                  expr = expr.property('toString').call([]);
                } else if (field is RelationFieldImpl) {
                  // Skip fields with relationship

                  continue;
                } else if (ctx.columns[field.displayName]?.type ==
                    ColumnType.json) {
                  expr = refer('json')
                      .property('decode')
                      .call([expr.asA(refer('String'))])
                      .asA(type);
                } else if (floatTypes.contains(ctx.columns[fieldName]?.type)) {
                  //expr = refer('double')
                  //    .property('tryParse')
                  //    .call([expr.property('toString').call([])]);
                  expr = refer('mapToDouble').call([expr]);
                } else if (fType is InterfaceType &&
                    fType.element is EnumElement) {
                  /*
                 * fields.contains('type') ? row[3] == null ? null : 
                 *     EnumType.values[(row[3] as int)] : null,
                 */

                  //if (field.name == "type") {
                  //print("=== Process enum $fieldName");
                  //}

                  var isNull = expr.equalTo(literalNull);
                  final parseExpression = _deserializeEnumExpression(
                    field,
                    expr,
                  );
                  expr = isNull.conditional(literalNull, parseExpression);
                } else if (fType.isDartCoreInt) {
                  expr = refer('mapToInt').call([expr]);
                } else if (fType.isDartCoreBool) {
                  // Generated Code: mapToBool(row[i])
                  expr = refer('mapToBool').call([expr]);
                } else if (fType.element?.displayName == 'DateTime') {
                  // Generated Code: mapToDateTime(row[i])
                  if (fType.nullabilitySuffix == NullabilitySuffix.question) {
                    expr = refer('mapToNullableDateTime').call([expr]);
                  } else {
                    expr = refer('mapToDateTime').call([expr]);
                  }
                } else {
                  // Generated Code: (row[i] as type?)
                  expr = expr.asA(type);
                }

                Expression defaultRef = refer('null');
                if (fType.nullabilitySuffix != NullabilitySuffix.question) {
                  if (fType.isDartCoreString) {
                    defaultRef = CodeExpression(Code('\'\''));
                  } else if (fType.isDartCoreBool) {
                    defaultRef = CodeExpression(Code('false'));
                  } else if (fType.isDartCoreDouble) {
                    defaultRef = CodeExpression(Code('0.0'));
                  } else if (fType.isDartCoreInt || fType.isDartCoreNum) {
                    defaultRef = CodeExpression(Code('0'));
                  } else if (fType.element?.displayName == 'DateTime') {
                    defaultRef = CodeExpression(
                      Code('DateTime.parse("1970-01-01 00:00:00")'),
                    );
                  } else if (fType.isDartCoreList) {
                    defaultRef = CodeExpression(Code('[]'));
                  }
                }
                expr = refer('fields')
                    .property('contains')
                    .call([
                      literalString(
                        ctx.buildContext.resolveFieldName(fieldName)!,
                      ),
                    ])
                    .conditional(expr, defaultRef);
                args[fieldName] = expr;
              }

              b.statements.add(
                Code(
                  'if (row.every((x) => x == null)) { return Optional.empty(); }',
                ),
              );
              //b.addExpression(refer('0').assignVar('_index'));

              //b.addExpression(ctx.buildContext.modelClassType
              //    .newInstance([], args).assignVar('model'));
              b.addExpression(
                declareVar(
                  'model',
                ).assign(ctx.buildContext.modelClassType.newInstance([], args)),
              );

              // The joins, in the order the constructor makes them; a
              // @HasMany is loaded on its own ([loadRelations]).
              var joinIndex = 0;
              ctx.relations.forEach((name, relation) {
                if (!const [
                  RelationshipType.hasOne,
                  RelationshipType.belongsTo,
                ].contains(relation.type)) {
                  //log.warning('Unsupported relationship for field $name');
                  return;
                }

                //log.fine('Process relationship');
                var foreign = relation.foreign;
                if (foreign == null) {
                  log.warning('Foreign relationship for field $name is null');
                  return;
                }
                //log.fine('Detected relationship ${RelationshipType.belongsTo}');

                // Its columns, and those of its own joins, which are only
                // known at runtime, as a join of a cycle selects NULLs.
                var joined = refer('joinedRow')
                    .call([literalNum(joinIndex++), refer('row')]);

                // The query joined, whose joins are those of the row.
                var parsed = refer('_$name')
                    .property('parseRow')
                    .call([joined]);

                //var baseClass = '${foreign.buildContext.originalClassName}';
                //var modelClass =
                //    foreign.buildContext.modelClassNameRecase.pascalCase;
                // Assume: baseclass starts with "_"
                //'_${foreign.buildContext.modelClassNameRecase.pascalCase}';

                //if (relation.type == RelationshipType.hasMany) {
                //  parsed = literalList([parsed.asA(refer(modelClass))]);
                //parsed = literalList([parsed.asA(refer(baseClass))]);
                //  var pp = parsed.accept(DartEmitter(useNullSafetySyntax: true));
                //  parsed = CodeExpression(Code('$pp'));
                //Code('$pp.where((x) => x != null).toList()'));
                //}

                //var expr =
                //    refer('model').property('copyWith').call([], {name: parsed});
                //var block =
                //    Block((b) => b.addExpression(refer('model').assign(expr)));

                var stmt = declareVar('modelOpt').assign(parsed);
                //parsed.assignVar('modelOpt');
                //var e = refer('Optional').property('ifPresent').call([]);

                var code = Code('''
                     modelOpt.ifPresent((m) {
                      model = model.copyWith($name: m);
                  })
              ''');

                var block = Block((b) {
                  b.addExpression(stmt);
                  b.addExpression(CodeExpression(code));
                });

                var blockStr = block.accept(
                  DartEmitter(useNullSafetySyntax: true),
                );

                b.statements.add(Code('{ $blockStr }'));
              });

              b.addExpression(
                refer('Optional.of').call([refer('model')]).returned,
              );
            });
        }),
      );

      // deserialize
      clazz.methods.add(
        Method((m) {
          m
            ..name = 'deserialize'
            ..returns = refer('Optional<${rc.pascalCase}>')
            ..annotations.add(refer('override'))
            ..requiredParameters.add(
              Parameter(
                (b) => b
                  ..name = 'row'
                  ..type = refer('List'),
              ),
            )
            ..body = Block((b) {
              b.addExpression(refer('parseRow').call([refer('row')]).returned);
            });
        }),
      );

      // If there are any relations, we need some overrides.
      clazz.constructors.add(
        Constructor((b) {
          b
            ..optionalParameters.add(
              Parameter(
                (b) => b
                  ..named = true
                  ..name = 'parent'
                  ..toSuper = true,
              ),
            )
            ..optionalParameters.add(
              Parameter(
                (b) => b
                  ..named = true
                  ..name = 'trampoline'
                  ..type = refer('Set<String>?'),
              ),
            )
            ..body = Block((b) {
              b.statements.addAll([
                Code('trampoline ??= <String>{};'),
                Code('trampoline.add(tableName);'),
              ]);

              // Add any manual SQL expressions.
              ctx.columns.forEach((name, col) {
                if (col.hasExpression) {
                  var lhs = refer('expressions').index(
                    literalString(ctx.buildContext.resolveFieldName(name)!),
                  );
                  var rhs = literalString(col.expression!);
                  b.addExpression(lhs.assign(rhs));
                }
              });

              // Add a constructor that initializes _where
              b.addExpression(
                refer('_where')
                    .assign(queryWhereType.newInstance([refer('this')])),
              );

              // Note: this is where subquery fields for relations are added.
              ctx.relations.forEach((fieldName, relation) {
                //var name = ctx.buildContext.resolveFieldName(fieldName);
                if (relation.type == RelationshipType.belongsTo ||
                    relation.type == RelationshipType.hasOne ||
                    relation.type == RelationshipType.hasMany) {
                  //
                  //     @ManyToMany(_RoleUser) => relation.throughContext
                  //     List<_User> get users; => relation.foreign
                  //
                  var relationForeign = relation.foreign;
                  if (relationForeign == null) {
                    log.warning(
                      '$fieldName has no relationship in the context',
                    );
                    return;
                  }
                  var foreignQueryType = refer(
                    '${relationForeign.buildContext.modelClassNameRecase.pascalCase}Query',
                  );

                  // A @HasMany is loaded with a query of its own, after the
                  // records ([loadRelations]), as a join would give a row
                  // per item. A many-to-many has none to customize.
                  if (relation.type == RelationshipType.hasMany) {
                    if (!relation.isManyToMany) {
                      clazz
                        ..fields.add(
                          Field(
                            (b) => b
                              ..name = '_$fieldName'
                              ..late = true
                              ..modifier = FieldModifier.final$
                              ..type = foreignQueryType
                              // Lazily, so a cycle of relations ends.
                              ..assignment = foreignQueryType
                                  .newInstance([])
                                  .code,
                          ),
                        )
                        ..methods.add(
                          Method(
                            (b) => b
                              ..name = fieldName
                              ..type = MethodType.getter
                              ..returns = foreignQueryType
                              ..docs.add(
                                '/// The query [$fieldName] are loaded '
                                'with, whose conditions and order apply.',
                              )
                              ..body = refer('_$fieldName').returned.statement,
                          ),
                        );
                    }
                    return;
                  }

                  var additionalStrs = relationForeign.effectiveFields.map(
                    (f) => relationForeign.buildContext.resolveFieldName(
                      f.displayName,
                    ),
                  );

                  var additionalFields = <Expression>[];
                  for (var element in additionalStrs) {
                    if (element != null) {
                      additionalFields.add(literalString(element));
                    }
                  }

                  var joinArgs = <Expression>[];
                  for (var element in [
                    relation.localKey,
                    relation.foreignKey,
                  ]) {
                    if (element != null) {
                      joinArgs.add(literalString(element));
                    }
                  }

                  // A field for each join, `_field`, and a getter, `field`,
                  // that returns the subquery object, so that users can
                  // customize the generated query.
                  clazz
                    ..fields.add(
                      Field(
                        (b) => b
                          ..name = '_$fieldName'
                          ..late = true
                          ..type = foreignQueryType,
                      ),
                    )
                    ..methods.add(
                      Method(
                        (b) => b
                          ..name = fieldName
                          ..type = MethodType.getter
                          ..returns = foreignQueryType
                          ..body = refer('_$fieldName').returned.statement,
                      ),
                    );

                  // Assign a value to `_field`.
                  var queryInstantiation = foreignQueryType.newInstance([], {
                    'trampoline': refer('trampoline'),
                    'parent': refer('this'),
                  });
                  joinArgs.insert(
                    0,
                    refer('_$fieldName').assign(queryInstantiation),
                  );

                  var joinType = relation.joinTypeString;
                  b.addExpression(
                    refer(joinType).call(joinArgs, {
                      'additionalFields': literalConstList(
                        additionalFields.toList(),
                      ),
                      'trampoline': refer('trampoline'),
                    }),
                  );
                }
              });
            });
        }),
      );

      // The relations that are not joined, each loaded with a query of its
      // own, for all the records at once.
      var loadBody = _loadRelationsBody(ctx);
      if (loadBody != null) {
        var type = ctx.buildContext.modelClassType.accept(
          DartEmitter(useNullSafetySyntax: true),
        );
        clazz.methods
          ..add(
            Method(
              (b) => b
                ..name = 'loadsRelations'
                ..type = MethodType.getter
                ..annotations.add(refer('override'))
                ..returns = refer('bool')
                ..lambda = true
                ..body = literalTrue.code,
            ),
          )
          ..add(
            Method(
              (b) => b
                ..name = 'loadRelations'
                ..annotations.add(refer('override'))
                ..modifier = MethodModifier.async
                ..returns = refer('Future<List<$type>>')
                ..requiredParameters.addAll([
                  Parameter(
                    (b) => b
                      ..name = 'executor'
                      ..type = refer('QueryExecutor'),
                  ),
                  Parameter(
                    (b) => b
                      ..name = 'rows'
                      ..type = refer('List<List>'),
                  ),
                  Parameter(
                    (b) => b
                      ..name = 'records'
                      ..type = refer('List<$type>'),
                  ),
                  Parameter(
                    (b) => b
                      ..name = 'loading'
                      ..type = refer('Set<String>'),
                  ),
                ])
                ..body = Code(loadBody),
            ),
          );
      }
    });
  }

  /// Generate "Model"QueryWhere class
  Class buildWhereClass(OrmBuildContext ctx) {
    return Class((clazz) {
      var rc = ctx.buildContext.modelClassNameRecase;

      log.info('Generating ${rc.pascalCase}QueryWhere');

      clazz
        ..name = '${rc.pascalCase}QueryWhere'
        ..extend = refer('QueryWhere');

      // Build expressionBuilders getter
      clazz.methods.add(
        Method((m) {
          m
            ..name = 'expressionBuilders'
            ..returns = refer('List<SqlExpressionBuilder>')
            ..annotations.add(refer('override'))
            ..type = MethodType.getter
            ..body = Block((b) {
              var references = ctx.effectiveNormalFields.map(
                (f) => refer(f.displayName),
              );
              b.addExpression(literalList(references).returned);
            });
        }),
      );

      var initializers = <Code>[];

      // Add builders for each field
      for (var field in ctx.effectiveNormalFields) {
        String name = field.displayName;

        var args = <Expression>[];
        DartType type;
        Reference builderType;

        try {
          type = ctx.buildContext.resolveSerializedFieldType(name);
        } on StateError {
          type = field.type;
        }

        if (const TypeChecker.typeNamed(int).isExactlyType(type) ||
            const TypeChecker.typeNamed(double).isExactlyType(type) ||
            isSpecialId(ctx, field)) {
          var typeName = type.getDisplayString().replaceAll('?', '');
          if (isSpecialId(ctx, field)) {
            typeName = 'int';
          }
          //log.fine('$name type = [$typeName]');
          builderType = TypeReference(
            (b) => b
              ..symbol = 'NumericSqlExpressionBuilder'
              ..types.add(refer(typeName)),
          );
        } else if (type is InterfaceType && type.element is EnumElement) {
          builderType = TypeReference(
            (b) => b
              ..symbol = 'EnumSqlExpressionBuilder'
              ..types.add(convertTypeReference(type)),
          );

          var question = type.nullabilitySuffix == NullabilitySuffix.question
              ? '?'
              : '';
          args.add(CodeExpression(Code('(v) => v$question.index as int')));
        } else if (const TypeChecker.typeNamed(String).isExactlyType(type)) {
          builderType = refer('StringSqlExpressionBuilder');
        } else if (const TypeChecker.typeNamed(bool).isExactlyType(type)) {
          builderType = refer('BooleanSqlExpressionBuilder');
        } else if (const TypeChecker.typeNamed(DateTime).isExactlyType(type)) {
          builderType = refer('DateTimeSqlExpressionBuilder');
        } else if (const TypeChecker.typeNamed(Map)
            .isAssignableFromType(type)) {
          builderType = refer('MapSqlExpressionBuilder');
        } else if (const TypeChecker.typeNamed(List)
            .isAssignableFromType(type)) {
          builderType = refer('ListSqlExpressionBuilder');

          // Detect relationship
        } else if (name.endsWith('Id')) {
          log.fine('Foreign Relationship detected = $name');
          var relation = ctx.relations[name.substring(0, name.length - 2)];
          if (relation != null) {
            //if (relation?.type != RelationshipType.belongsTo) {
            //  continue;
            //} else {
            builderType = TypeReference(
              (b) => b
                ..symbol = 'NumericSqlExpressionBuilder'
                ..types.add(refer('int')),
            );
            //name = relation?.localKey;
            //}
          } else {
            log.warning(
              'Cannot generate ORM code for field ${field.displayName} of type ${field.type}',
            );
            continue;
          }
        } else {
          log.warning(
            'Cannot generate ORM code for field ${field.displayName} of type ${field.type}',
          );
          //ctx.relations.forEach((key, value) {
          //  log.fine('key: $key, value: $value');
          //});
          //throw UnsupportedError(
          //    'Cannot generate ORM code for field of type ${field.type.getDisplayString(withNullability: false)}.');
          continue;
        }

        // FIXME: Crashed here.
        clazz.fields.add(
          Field((b) {
            //log.fine('Field: $name, BuilderType: $builderType');

            b
              ..name = name
              ..modifier = FieldModifier.final$
              ..type = builderType;

            var literal = ctx.buildContext.resolveFieldName(field.displayName);
            if (literal != null) {
              //log.fine('Literal = ${field.name}  $literal');
              initializers.add(
                refer(field.displayName)
                    .assign(
                      builderType.newInstance(
                        [
                          refer('query'),
                          literalString(literal),
                        ].followedBy(args),
                      ),
                    )
                    .code,
              );
            } else {
              log.warning('Literal ${field.displayName} is null');
            }
          }),
        );
      }

      // Now, just add a constructor that initializes each builder.
      clazz.constructors.add(
        Constructor((b) {
          b
            ..requiredParameters.add(
              Parameter(
                (b) => b
                  ..name = 'query'
                  ..type = refer('${rc.pascalCase}Query'),
              ),
            )
            ..initializers.addAll(initializers);
        }),
      );
    });
  }

  /// Generate "Model"QueryValues class
  Class buildValuesClass(OrmBuildContext ctx) {
    return Class((clazz) {
      var rc = ctx.buildContext.modelClassNameRecase;

      log.info('Generating ${rc.pascalCase}QueryValues');

      clazz
        ..name = '${rc.pascalCase}QueryValues'
        ..extend = refer('MapQueryValues');

      // Override casts so that we can cast Lists
      clazz.methods.add(
        Method((b) {
          b
            ..name = 'casts'
            ..returns = refer('Map<String, String>')
            ..annotations.add(refer('override'))
            ..type = MethodType.getter
            ..body = Block((b) {
              var args = <String?, Expression>{};

              for (var field in ctx.effectiveFields) {
                var fType = field.type;
                var name = ctx.buildContext.resolveFieldName(field.displayName);
                var type = ctx.columns[field.displayName]?.type;
                if (type == null) continue;
                if (const TypeChecker.typeNamed(List)
                    .isAssignableFromType(fType)) {
                  args[name] = literalString(type.name);
                }

                /* else if (floatTypes.contains(type)) {
                args[name] = literalString(type.name);
              } */
              }

              b.addExpression(literalMap(args).returned);
            });
        }),
      );

      // Each field generates a getter and setter
      for (var field in ctx.effectiveNormalFields) {
        var fType = field.type;
        var name = ctx.buildContext.resolveFieldName(field.displayName);
        // The key of a relation is null until it is set, and its column, as
        // the relation may be null.
        var type = convertTypeReference(
          field.type,
          forceNullable: field is RelationFieldImpl,
        );

        clazz.methods.add(
          Method((b) {
            var value = refer('values').index(literalString(name!));

            if (fType is InterfaceType && fType.element is EnumElement) {
              value = _deserializeEnumExpression(field, value);
            } else if (const TypeChecker.typeNamed(List)
                .isAssignableFromType(fType)) {
              value = refer('json')
                  .property('decode')
                  .call([value.asA(refer('String'))])
                  .property('cast')
                  .call([]);
            } else if (floatTypes.contains(
              ctx.columns[field.displayName]?.type,
            )) {
              // Skip using casts on double
              value = value
                  .asA(refer('double?'))
                  .ifNullThen(CodeExpression(Code('0.0')));
              //value = refer('double')
              //    .property('tryParse')
              //    .call([value.asA(refer('String'))]).ifNullThen(
              //        CodeExpression(Code('0.0')));
            } else {
              value = value.asA(type);
            }

            b
              ..name = field.displayName
              ..type = MethodType.getter
              ..returns = type
              ..body = Block((b) => b.addExpression(value.returned));
          }),
        );

        clazz.methods.add(
          Method((b) {
            Expression value = refer('value');

            if (fType is InterfaceType && fType.element is EnumElement) {
              value = _serializeEnumExpression(field, value);
            } else if (const TypeChecker.typeNamed(List)
                .isAssignableFromType(fType)) {
              value = refer('json').property('encode').call([value]);
            }

            /* else if (floatTypes.contains(ctx.columns[field.name]?.type)) {
            value = value.property('toString').call([]);
          } */

            b
              ..name = field.displayName
              ..type = MethodType.setter
              ..requiredParameters.add(
                Parameter(
                  (b) => b
                    ..name = 'value'
                    ..type = type,
                ),
              )
              ..body = refer('values')
                  .index(literalString(name!))
                  .assign(value)
                  .code;
          }),
        );
      }

      // Add model
      clazz.methods.add(
        Method((b) {
          b
            ..name = 'copyFrom'
            ..returns = refer('void')
            ..requiredParameters.add(
              Parameter(
                (b) => b
                  ..name = 'model'
                  ..type = ctx.buildContext.modelClassType,
              ),
            )
            ..body = Block((b) {
              for (var field in ctx.effectiveNormalFields) {
                if (isSpecialId(ctx, field) || field is RelationFieldImpl) {
                  continue;
                }
                b.addExpression(
                  refer(field.displayName)
                      .assign(refer('model').property(field.displayName)),
                );
              }

              for (var field in ctx.effectiveNormalFields) {
                //print("=== Field: ${field.displayName}");
                if (field is RelationFieldImpl) {
                  //print("=== RelationFieldImpl2: ${field.displayName}");
                  var customField = field;
                  var original = customField.originalFieldName;
                  var prop = refer('model').property(original);

                  // Add only if present
                  var target = refer('values').index(
                    literalString(
                      ctx.buildContext.resolveFieldName(field.displayName)!,
                    ),
                  );

                  var foreign =
                      customField.relationship.throughContext ??
                      customField.relationship.foreign;
                  var foreignField = customField.relationship.findForeignField(
                    ctx,
                  );

                  var parsedId = prop.nullSafeProperty(
                    foreignField.displayName,
                  );

                  //log.fine('Foreign field => ${foreignField.name}');
                  //if (foreignField.type.nullabilitySuffix ==
                  //    NullabilitySuffix.question) {
                  //  parsedId = prop.nullSafeProperty(foreignField.name);
                  //}

                  var cond = prop.notEqualTo(literalNull);

                  if (foreign != null && isSpecialId(foreign, foreignField)) {
                    // A Model's id is a String; the column is an int. Leave
                    // the column unset until the related model has an id,
                    // and reject an id that is not a number.
                    cond = parsedId.notEqualTo(literalNull);
                    parsedId = refer('int').property('parse').call([
                      prop.nullChecked
                          .property(foreignField.displayName)
                          .nullChecked,
                    ]);
                  }
                  var condStr = cond.accept(
                    DartEmitter(useNullSafetySyntax: true),
                  );
                  var blkStr = Block(
                    (b) => b.addExpression(target.assign(parsedId)),
                  ).accept(DartEmitter(useNullSafetySyntax: true));
                  var ifStmt = Code('if ($condStr) { $blkStr }');
                  b.statements.add(ifStmt);
                }
              }
            });
        }),
      );
    });
  }

  /// Retrieve the [Expression] to parse a serialized enumeration field.
  /// Takes into account the [SerializableField] properties.
  /// Defaults to `enum.values[index as int]`
  Expression _deserializeEnumExpression(OrmField field, Expression expr) {
    Reference enumType = convertTypeReference(
      field.type,
      ignoreNullabilityCheck: true,
    );
    const TypeChecker serializableFieldTypeChecker = TypeChecker.typeNamed(
      SerializableField,
    );
    // A relation's column has no annotations of its own.
    final annotation = field is ClassOrmField
        ? serializableFieldTypeChecker.firstAnnotationOf(field.element)
        : null;
    Expression? parseExpr;
    if (null != annotation) {
      final deserializer = annotation.getField('deserializer')?.toSymbolValue();
      if (null != deserializer) {
        var type = 'int';
        final serializesTo = annotation.getField('serializesTo')?.toTypeValue();
        if (null != serializesTo) {
          type = serializesTo.element!.displayName;
        }
        parseExpr = Reference(deserializer).call([expr.asA(refer(type))]);
      }
    }

    //return parseExpr ??
    //    enumType.property('values').index(expr.asA(refer('int')));

    if (parseExpr != null) {
      return parseExpr;
    }

    return enumType.property('values').index(refer('mapToInt').call([expr]));
  }

  /// Retrieve the [Expression] to serialize the enumeration field.
  /// Takes into account the [SerializableField] properties.
  Expression _serializeEnumExpression(OrmField field, Expression expr) {
    const TypeChecker serializableFieldTypeChecker = TypeChecker.typeNamed(
      SerializableField,
    );
    // A relation's column has no annotations of its own.
    final annotation = field is ClassOrmField
        ? serializableFieldTypeChecker.firstAnnotationOf(field.element)
        : null;
    Expression? parseExpr;
    if (null != annotation) {
      final serializer = annotation.getField('serializer')?.toSymbolValue();
      if (null != serializer) {
        parseExpr = Reference(serializer).call([expr]);
      }
    }
    return parseExpr ?? CodeExpression(Code('value?.index'));
  }
}

/// Whether a record of [ctx] has relations that are not joined: a
/// @HasMany, or a @HasOne or @BelongsTo of a model that has, but not of
/// [seen], which a cycle of relations leads back to.
bool _loadsRelations(OrmBuildContext ctx, [Set<String>? seen]) {
  seen ??= {};
  if (!seen.add(ctx.tableName)) return false;
  return ctx.relations.values.any((relation) {
    var foreign = relation.foreign;
    if (foreign == null) return false;
    return switch (relation.type) {
      RelationshipType.hasMany => true,
      RelationshipType.hasOne ||
      RelationshipType.belongsTo => _loadsRelations(foreign, seen),
      _ => false,
    };
  });
}

/// The relation of the "through" model of a many-to-many [relation] of
/// [ctx] that points to its other model.
RelationshipReader _throughRelation(
  OrmBuildContext ctx,
  RelationshipReader relation,
) {
  var through = relation.throughContext!;
  var foreign = relation.foreign!;
  return through.relations.values.firstWhere(
    (e) => e.foreignTable == foreign.tableName,
    orElse: () =>
        throw '${ctx.buildContext.modelClassName} has a many-to-many '
            'relationship to ${foreign.buildContext.modelClassName} through '
            '${through.buildContext.modelClassName}, but '
            '${through.buildContext.modelClassName} has no relation pointing '
            'to ${foreign.buildContext.modelClassName}.',
  );
}

/// The body of `loadRelations` of the query of [ctx], or `null` if all its
/// relations are joined.
String? _loadRelationsBody(OrmBuildContext ctx) {
  if (!_loadsRelations(ctx)) return null;
  var b = StringBuffer('if (records.isEmpty) return records;\n');
  var copies = <String>[];
  var usesIndex = false;
  // The joins, in the order the constructor makes them.
  var joinIndex = 0;
  ctx.relations.forEach((name, relation) {
    var foreign = relation.foreign;
    if (foreign == null) return;
    var field = ctx.buildContext.fields.firstWhere(
      (f) => f.displayName == name,
    );
    var isNullable = field.type.nullabilitySuffix == NullabilitySuffix.question;
    var model = foreign.buildContext.modelClassNameRecase.pascalCase;
    var table = foreign.tableName;

    if (relation.type == RelationshipType.hasMany) {
      usesIndex = true;
      var localKey = relation.localKey ?? 'id';
      var keys = "[for (var row in rows) valueOf('$localKey', row)]";
      var keyOfRow = "'\${valueOf('$localKey', rows[i])}'";
      if (relation.isManyToMany) {
        var through = _throughRelation(ctx, relation);
        b.writeln('''
          // The other ends of the many-to-many, then their records.
          var ${name}Pivot = loading.contains('$table')
              ? null
              : await Query.pivotKeys(
                  executor,
                  '${relation.throughContext!.tableName}',
                  '${relation.foreignKey}',
                  '${through.localKey}',
                  $keys,
                );
          var ${name}ByKey = ${name}Pivot == null
              ? null
              : await ${model}Query().getByKeys(
                  executor,
                  '${through.foreignKey}',
                  ${name}Pivot.values.expand((k) => k),
                  loading,
                );''');
        copies.add(
          '$name: ${name}ByKey == null ? r.$name : '
          '[for (var k in ${name}Pivot![$keyOfRow] ?? const []) '
          "...?${name}ByKey['\$k']]",
        );
      } else {
        b.writeln('''
          var ${name}ByKey = loading.contains('$table')
              ? null
              : await _$name.getByKeys(
                  executor,
                  '${relation.foreignKey}',
                  $keys,
                  loading,
                );''');
        copies.add(
          '$name: ${name}ByKey == null ? r.$name : '
          '[...?${name}ByKey[$keyOfRow]]',
        );
      }
    } else if (relation.type == RelationshipType.hasOne ||
        relation.type == RelationshipType.belongsTo) {
      var index = joinIndex++;
      if (!_loadsRelations(foreign)) return;
      // The relations of the records joined, from their columns.
      var present = isNullable ? 'if (r.$name != null) ' : '';
      b.writeln('''
          var ${name}Loaded = loading.contains('$table')
              ? null
              : (await _$name.loadRelations(
                  executor,
                  [for (var (i, r) in records.indexed) ${present}joinedRow($index, rows[i])],
                  [for (var r in records) $present r.$name as $model],
                  {...loading, '$table'},
                )).iterator;''');
      var absent = isNullable ? ' || r.$name == null' : '';
      copies.add(
        '$name: ${name}Loaded == null$absent '
        '? r.$name : (${name}Loaded..moveNext()).current',
      );
    }
  });
  var loop = usesIndex
      ? 'for (var (i, r) in records.indexed)'
      : 'for (var r in records)';
  b.writeln('return [$loop r.copyWith(${copies.join(', ')})];');
  return b.toString();
}
