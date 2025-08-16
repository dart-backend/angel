part of 'serialize_generator.dart';

class SerializerGenerator extends GeneratorForAnnotation<Serializable> {
  final bool autoSnakeCaseNames;

  const SerializerGenerator({this.autoSnakeCaseNames = true});

  @override
  Future<String?> generateForAnnotatedElement(
    Element2 element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    log.fine('Running SerializerGenerator');

    if (element.kind != ElementKind.CLASS) {
      throw 'Only classes can be annotated with a @Serializable() annotation.';
    }

    var ctx = await buildContext(
      element as ClassElement2,
      annotation,
      buildStep,
      buildStep.resolver,
      !autoSnakeCaseNames,
    );

    if (ctx == null) {
      log.severe('Invalid builder context');
      throw 'Invalid builder context';
    }

    var serializers = annotation.peek('serializers')?.listValue ?? [];

    if (serializers.isEmpty) {
      log.severe("No Serializers");
      return null;
    }

    // Check if any serializer is recognized
    if (!serializers.any((s) => Serializers.all.contains(s.toIntValue()))) {
      log.severe("No recognizable Serializers");
      return null;
    }

    var lib = Library((b) {
      generateClass(
        serializers.map((s) => s.toIntValue() ?? 0).toList(),
        ctx,
        b,
      );
      generateFieldsClass(ctx, b);
    });

    var buf = lib.accept(DartEmitter(useNullSafetySyntax: true));
    return buf.toString();
  }

  /// Generate a serializer class.
  void generateClass(
    List<int> serializers,
    BuildContext ctx,
    LibraryBuilder file,
  ) {
    log.fine('Generate serializer class');

    // Generate canonical codecs, etc.
    var pascal = ctx.modelClassNameRecase.pascalCase.replaceAll('?', '');
    var camel = ctx.modelClassNameRecase.camelCase.replaceAll('?', '');

    log.fine('Generating ${pascal}Serializer');

    if (ctx.constructorParameters.isEmpty) {
      log.fine("Constructor is empty");

      file.body.add(
        Code('''
const ${pascal}Serializer ${camel}Serializer = ${pascal}Serializer();

class ${pascal}Encoder extends Converter<$pascal, Map> {
  const ${pascal}Encoder();

  @override
  Map convert($pascal model) => ${pascal}Serializer.toMap(model);
}

class ${pascal}Decoder extends Converter<Map, $pascal> {
  const ${pascal}Decoder();
  
  @override
  $pascal convert(Map map) => ${pascal}Serializer.fromMap(map);
}
    '''),
      );
    }

    file.body.add(
      Class((clazz) {
        clazz.name = '${pascal}Serializer';
        if (ctx.constructorParameters.isEmpty) {
          clazz.extend = TypeReference(
            (b) => b
              ..symbol = 'Codec'
              ..types.addAll([ctx.modelClassType, refer('Map')]),
          );

          // Add constructor, Codec impl, etc.
          clazz.constructors.add(Constructor((b) => b..constant = true));
          clazz.methods.add(
            Method(
              (b) => b
                ..name = 'encoder'
                ..returns = refer('${pascal}Encoder')
                ..type = MethodType.getter
                ..annotations.add(refer('override'))
                ..body = refer('${pascal}Encoder').constInstance([]).code,
            ),
          );
          clazz.methods.add(
            Method(
              (b) => b
                ..name = 'decoder'
                ..returns = refer('${pascal}Decoder')
                ..type = MethodType.getter
                ..annotations.add(refer('override'))
                ..body = refer('${pascal}Decoder').constInstance([]).code,
            ),
          );
        } else {
          clazz.abstract = true;
        }

        if (serializers.contains(Serializers.map)) {
          generateFromMapMethod(clazz, ctx, file);
        }

        if (serializers.contains(Serializers.map) ||
            serializers.contains(Serializers.json)) {
          generateToMapMethod(clazz, ctx, file);
        }
      }),
    );
  }

  // Generate toMapMethod
  void generateToMapMethod(
    ClassBuilder clazz,
    BuildContext ctx,
    LibraryBuilder file,
  ) {
    var originalClassName = ctx.originalClassName;
    if (originalClassName == null) {
      log.warning('Unable to generate toMap(), classname is null');
      return;
    }
    clazz.methods.add(
      Method((method) {
        method
          ..static = true
          ..name = 'toMap'
          ..returns = Reference('Map<String, dynamic>')
          ..requiredParameters.add(
            Parameter((b) {
              b
                ..name = 'model'
                ..type = TypeReference(
                  (b) => b
                    ..symbol = originalClassName
                    ..isNullable = true,
                );
            }),
          );

        var buf = StringBuffer();

        /*
      ctx.requiredFields.forEach((key, msg) {
        if (ctx.excluded[key]?.canSerialize == false) return;
        buf.writeln('''
        if (model.$key == null) {
          throw FormatException("$msg");
        }
        ''');
      });
      */

        buf.writeln('return {');
        var i = 0;

        // Add named parameters
        for (var field in ctx.fields) {
          var type = ctx.resolveSerializedFieldType(field.name3 ?? '');

          // Skip excluded fields
          if (ctx.excluded[field.name3]?.canSerialize == false) continue;

          var alias = ctx.resolveFieldName(field.name3 ?? '');

          if (i++ > 0) buf.write(', ');

          var serializedRepresentation = 'model.${field.name3}';

          String serializerToMap(ReCase rc, String value) {
            // if (rc.pascalCase == ctx.modelClassName) {
            //   return '($value)?.toJson()';
            // }

            var genClass = getGeneratedModelClassName(
              rc.pascalCase.replaceAll('?', ''),
            );
            return '${genClass}Serializer.toMap($value)';
          }

          var fieldNameSerializer = ctx.fieldInfo[field.name3]?.serializer;
          if (fieldNameSerializer != null) {
            var name = MirrorSystem.getName(fieldNameSerializer);
            serializedRepresentation = '$name(model.${field.name3})';
          }
          // Serialize dates
          else if (dateTimeTypeChecker.isAssignableFromType(type)) {
            var question =
                field.type.nullabilitySuffix == NullabilitySuffix.question
                ? "?"
                : "";
            serializedRepresentation =
                'model.${field.name3}$question.toIso8601String()';
          }
          // Serialize model classes via `XSerializer.toMap`
          else if (isModelClass(type)) {
            var rc = ReCase(type.getDisplayString());
            serializedRepresentation = serializerToMap(
              rc,
              'model.${field.name3}',
            );
          } else if (type is InterfaceType) {
            if (isListOfModelType(type)) {
              var name = type.typeArguments[0].getDisplayString();
              name = getGeneratedModelClassName(name);

              var rc = ReCase(name);
              var m = serializerToMap(rc, 'm');

              var question =
                  (field.type.nullabilitySuffix == NullabilitySuffix.question)
                  ? '?'
                  : '';
              serializedRepresentation =
                  'model.${field.name3}$question.map((m) => $m).toList()';
              log.fine('serializedRepresentation => $serializedRepresentation');
            } else if (isMapToModelType(type)) {
              var rc = ReCase(type.typeArguments[1].getDisplayString());
              serializedRepresentation =
                  '''model.${field.name3}.keys.fold({}, (map, key) {
              return map..[key] =
              ${serializerToMap(rc, 'model.${field.name3}[key]')};
            })''';
            } else if (type.element3 is Enum) {
              var convert =
                  (field.type.nullabilitySuffix == NullabilitySuffix.question)
                  ? '!'
                  : '';

              serializedRepresentation =
                  '''
            model.${field.name3} != null ?
              ${type.getDisplayString()}.values.indexOf(model.${field.name3}$convert)
              : null
            ''';
            } else if (const TypeChecker.fromRuntime(
              Uint8List,
            ).isAssignableFromType(type)) {
              var convert =
                  (field.type.nullabilitySuffix == NullabilitySuffix.question)
                  ? '!'
                  : '';

              serializedRepresentation =
                  '''
            model.${field.name3} != null ?
              base64.encode(model.${field.name3}$convert)
              : null
            ''';
            }
          }

          buf.write("'$alias': $serializedRepresentation");
        }

        buf.write('};');
        method.body = Block.of([
          Code(
            'if (model == null) { throw FormatException("Required field [model] cannot be null"); }',
          ),
          Code(buf.toString()),
        ]);
      }),
    );
  }

  // Generate fromMapMethod
  void generateFromMapMethod(
    ClassBuilder clazz,
    BuildContext ctx,
    LibraryBuilder file,
  ) {
    clazz.methods.add(
      Method((method) {
        method
          ..static = true
          ..name = 'fromMap'
          ..returns = ctx.modelClassType
          ..requiredParameters.add(
            Parameter(
              (b) => b
                ..name = 'map'
                ..type = Reference('Map'),
            ),
          );

        // Add all `super` params
        if (ctx.constructorParameters.isNotEmpty) {
          for (var param in ctx.constructorParameters) {
            method.requiredParameters.add(
              Parameter(
                (b) => b
                  ..name = param.name3 ?? ''
                  ..type = convertTypeReference(param.type),
              ),
            );
          }
        }

        var buf = StringBuffer();

        // Required Fields
        ctx.requiredFields.forEach((key, msg) {
          if (ctx.excluded[key]?.canDeserialize == false) return;
          var name = ctx.resolveFieldName(key);
          if (msg.contains("'")) {
            buf.writeln('''
            if (map['$name'] == null) {
              throw FormatException("$msg");
            }
          ''');
          } else {
            buf.writeln('''
            if (map['$name'] == null) {
              throw FormatException('$msg');
            }
          ''');
          }
        });

        buf.writeln('return ${ctx.modelClassName}(');
        var i = 0;

        // Parameters in the constructor
        for (var param in ctx.constructorParameters) {
          if (i++ > 0) buf.write(', ');
          buf.write(param.name3);
        }

        // Fields
        for (var field in ctx.fields) {
          var type = ctx.resolveSerializedFieldType(field.name3 ?? '');

          if (ctx.excluded[field.name3]?.canDeserialize == false) continue;

          var alias = ctx.resolveFieldName(field.name3 ?? '');

          if (i++ > 0) buf.write(', ');

          var deserializedRepresentation =
              "map['$alias'] as ${typeToString(type)}";

          if (type.nullabilitySuffix == NullabilitySuffix.question) {
            deserializedRepresentation += '?';
          }

          var defaultValue = 'null';
          var existingDefault = ctx.defaults[field.name3];

          if (existingDefault != null) {
            var d = dartObjectToString(existingDefault);
            if (d != null) {
              defaultValue = d;

              if (!deserializedRepresentation.endsWith("?")) {
                deserializedRepresentation += "?";
              }
            }
            deserializedRepresentation =
                '$deserializedRepresentation ?? $defaultValue';
          }

          var fieldNameDeserializer = ctx.fieldInfo[field.name3]?.deserializer;
          if (fieldNameDeserializer != null) {
            var name = MirrorSystem.getName(fieldNameDeserializer);
            deserializedRepresentation = "$name(map['$alias'])";
          } else if (dateTimeTypeChecker.isAssignableFromType(type)) {
            if (field.type.nullabilitySuffix != NullabilitySuffix.question) {
              if (defaultValue.toLowerCase() == 'null') {
                defaultValue = 'DateTime.parse("1970-01-01 00:00:00")';
              } else {
                defaultValue = 'DateTime.parse("$defaultValue")';
              }
            }
            deserializedRepresentation =
                "map['$alias'] != null ? "
                "(map['$alias'] is DateTime ? (map['$alias'] as DateTime) : DateTime.parse(map['$alias'].toString()))"
                ' : $defaultValue';
          }
          // Serialize model classes via `XSerializer.toMap`
          else if (isModelClass(type)) {
            var rc = ReCase(type.getDisplayString());

            var genClass = getGeneratedModelClassName(
              rc.pascalCase.replaceAll('?', ''),
            );
            deserializedRepresentation =
                "map['$alias'] != null"
                " ? ${genClass}Serializer.fromMap(map['$alias'] as Map)"
                ' : $defaultValue';
          } else if (type is InterfaceType) {
            if (isListOfModelType(type)) {
              if (defaultValue == 'null') {
                defaultValue = '[]';
              }
              var rc = ReCase(type.typeArguments[0].getDisplayString());

              var genClass = getGeneratedModelClassName(
                rc.pascalCase.replaceAll('?', ''),
              );

              deserializedRepresentation =
                  "map['$alias'] is Iterable"
                  " ? List.unmodifiable(((map['$alias'] as Iterable)"
                  '.whereType<Map>())'
                  '.map(${genClass}Serializer.fromMap))'
                  ' : $defaultValue';
            } else if (isMapToModelType(type)) {
              // TODO: This requires refractoring
              if (defaultValue == 'null') {
                defaultValue = '{}';
              }

              var rc = ReCase(type.typeArguments[1].getDisplayString());
              var genClass = getGeneratedModelClassName(
                rc.pascalCase.replaceAll('?', ''),
              );
              deserializedRepresentation =
                  '''
                map['$alias'] is Map
                  ? Map.unmodifiable((map['$alias'] as Map).keys.fold({}, (out, key) {
                       return out..[key] = ${genClass}Serializer
                        .fromMap(((map['$alias'] as Map)[key]) as Map);
                    }))
                  : $defaultValue
            ''';
            } else if (type.element3 is Enum) {
              deserializedRepresentation =
                  '''
            map['$alias'] is ${type.getDisplayString()}
              ? (map['$alias'] as ${type.getDisplayString()}) ?? $defaultValue
              :
              (
                map['$alias'] is int
                ? ${type.getDisplayString()}.values[map['$alias'] as int]
                : $defaultValue
              )
            ''';

              //log.warning('Code => $deserializedRepresentation');
            } else if (const TypeChecker.fromRuntime(
                  List,
                ).isAssignableFromType(type) &&
                type.typeArguments.length == 1) {
              if (defaultValue == 'null') {
                defaultValue = '[]';
              }
              var arg = convertTypeReference(
                type.typeArguments[0],
              ).accept(DartEmitter(useNullSafetySyntax: true));
              deserializedRepresentation =
                  '''
                map['$alias'] is Iterable
                  ? (map['$alias'] as Iterable).cast<$arg>().toList()
                  : $defaultValue
                ''';
            } else if (const TypeChecker.fromRuntime(
                  Map,
                ).isAssignableFromType(type) &&
                type.typeArguments.length == 2) {
              var key = convertTypeReference(
                type.typeArguments[0],
              ).accept(DartEmitter(useNullSafetySyntax: true));
              var value = convertTypeReference(
                type.typeArguments[1],
              ).accept(DartEmitter(useNullSafetySyntax: true));

              if (defaultValue == 'null') {
                defaultValue = '{}';
              }
              deserializedRepresentation =
                  '''
                map['$alias'] is Map
                  ? (map['$alias'] as Map).cast<$key, $value>()
                  : $defaultValue
                ''';
            } else if (const TypeChecker.fromRuntime(
              Uint8List,
            ).isAssignableFromType(type)) {
              deserializedRepresentation =
                  '''
            map['$alias'] is Uint8List
              ? (map['$alias'] as Uint8List)
              :
              (
                map['$alias'] is Iterable<int>
                  ? Uint8List.fromList((map['$alias'] as Iterable<int>).toList())
                  :
                  (
                    map['$alias'] is String
                      ? Uint8List.fromList(base64.decode(map['$alias'] as String))
                      : $defaultValue
                  )
              )
            ''';
            }
          }

          buf.write('${field.name3}: $deserializedRepresentation');
        }

        buf.write(');');
        method.body = Code(buf.toString());
      }),
    );
  }

  void generateFieldsClass(BuildContext ctx, LibraryBuilder file) {
    //log.fine('Generate serializer fields');

    file.body.add(
      Class((clazz) {
        clazz
          ..abstract = true
          ..name = '${ctx.modelClassNameRecase.pascalCase}Fields';

        clazz.fields.add(
          Field((b) {
            b
              ..static = true
              ..modifier = FieldModifier.constant
              ..type = TypeReference(
                (b) => b
                  ..symbol = 'List'
                  ..types.add(refer('String')),
              )
              ..name = 'allFields'
              ..assignment = literalConstList(
                ctx.fields.map((f) => refer(f.name3 ?? '')).toList(),
                refer('String'),
              ).code;
          }),
        );

        for (var field in ctx.fields) {
          clazz.fields.add(
            Field((b) {
              b
                ..static = true
                ..modifier = FieldModifier.constant
                ..type = Reference('String')
                ..name = field.name3
                ..assignment = Code(
                  "'${ctx.resolveFieldName(field.name3 ?? '')}'",
                );
            }),
          );
        }
      }),
    );
  }
}
