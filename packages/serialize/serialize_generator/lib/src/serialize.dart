part of 'serialize_generator.dart';

class SerializerGenerator extends GeneratorForAnnotation<Serializable> {
  final bool autoSnakeCaseNames;

  const SerializerGenerator({this.autoSnakeCaseNames = true});

  @override
  Future<String?> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    log.fine('Running SerializerGenerator');

    if (element.kind != ElementKind.CLASS) {
      throw 'Only classes can be annotated with a @Serializable() annotation.';
    }

    var ctx = await buildContext(
      element as ClassElement,
      annotation,
      buildStep,
      buildStep.resolver,
      !autoSnakeCaseNames,
    );

    if (ctx == null) {
      log.severe('Invalid builder context');
      throw 'Invalid builder context';
    }

    var serializers = readSerializers(annotation);

    if (serializers.isEmpty) {
      log.severe("No Serializers");
      return null;
    }

    var lib = Library((b) {
      // Of toMap with map or json, as toJson calls it, and of fromMap, and
      // the codec, encoder and decoder that call it, with map only, as
      // typescript is a builder of its own.
      if (serializers.contains(Serializers.map) ||
          serializers.contains(Serializers.json)) {
        generateClass(serializers, ctx, b);
      }
      generateFieldsClass(ctx, b);
    });

    var buf = lib.accept(DartEmitter(useNullSafetySyntax: true));
    return buf.toString();
  }

  /// Generate a serializer class.
  void generateClass(
    List<Serializers> serializers,
    BuildContext ctx,
    LibraryBuilder file,
  ) {
    log.fine('Generate serializer class');

    // Generate canonical codecs, etc.
    var pascal = ctx.modelClassNameRecase.pascalCase.replaceAll('?', '');
    var camel = ctx.modelClassNameRecase.camelCase.replaceAll('?', '');

    log.fine('Generating ${pascal}Serializer');

    // A codec, of an encoder and a decoder, which call toMap and fromMap, of
    // a model of map, which has fromMap; with json only, it is the abstract
    // class of toMap, which toJson calls.
    var codec =
        ctx.ownConstructorParameters.isEmpty &&
        serializers.contains(Serializers.map);

    if (codec) {
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
        if (codec) {
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

        _addJsonSchema(clazz, ctx);

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

        // A required field (`isNullable: false`) that is null throws, as
        // `fromMap` does of a map without it.
        ctx.requiredFields.forEach((key, msg) {
          if (ctx.excluded[key]?.canSerialize == false) return;
          buf.writeln('''
        if (model.$key == null) {
          throw FormatException(${_dartLiteral(msg)});
        }
        ''');
        });

        buf.writeln('return {');
        var i = 0;

        // Add named parameters
        for (var field in ctx.fields) {
          var type = ctx.resolveSerializedFieldType(field.name ?? '');

          // Skip excluded fields
          if (ctx.excluded[field.name]?.canSerialize == false) continue;

          var alias = ctx.resolveFieldName(field.name ?? '');

          if (i++ > 0) buf.write(', ');

          var serializedRepresentation = 'model.${field.name}';

          String serializerToMap(DartType model, String value) =>
              '${modelClassNameOf(model)}Serializer.toMap($value)';

          var fieldNameSerializer = ctx.fieldInfo[field.name]?.serializer;
          if (fieldNameSerializer != null) {
            serializedRepresentation =
                '$fieldNameSerializer(model.${field.name})';
          }
          // Serialize dates
          else if (dateTimeTypeChecker.isAssignableFromType(type)) {
            var question =
                field.type.nullabilitySuffix == NullabilitySuffix.question
                ? "?"
                : "";
            serializedRepresentation =
                'model.${field.name}$question.toIso8601String()';
          }
          // Serialize model classes via `XSerializer.toMap`
          else if (isModelClass(type)) {
            serializedRepresentation = serializerToMap(
              type,
              'model.${field.name}',
            );
            // `toMap` throws for `null`.
            if (field.type.nullabilitySuffix == NullabilitySuffix.question) {
              serializedRepresentation =
                  'model.${field.name} == null ? null : $serializedRepresentation';
            }
          } else if (type is InterfaceType) {
            if (isListOfModelType(type)) {
              var m = serializerToMap(type.typeArguments[0], 'm');

              var question =
                  (field.type.nullabilitySuffix == NullabilitySuffix.question)
                  ? '?'
                  : '';
              serializedRepresentation =
                  'model.${field.name}$question.map((m) => $m).toList()';
              log.fine('serializedRepresentation => $serializedRepresentation');
            } else if (isMapToModelType(type)) {
              var nullable =
                  field.type.nullabilitySuffix == NullabilitySuffix.question;
              var bang = nullable ? '!' : '';
              serializedRepresentation =
                  '''model.${field.name}$bang.keys.fold({}, (map, key) {
              return map..[key] =
              ${serializerToMap(type.typeArguments[1], 'model.${field.name}$bang[key]')};
            })''';
              if (nullable) {
                serializedRepresentation =
                    'model.${field.name} == null ? null : $serializedRepresentation';
              }
            } else if (type.element is EnumElement) {
              // Its index, which `fromMap` reads back.
              var enumType =
                  (typeToString(type, ctx.clazz.library) ??
                          type.element.name ??
                          '')
                      .replaceAll('?', '');
              var index = '$enumType.values.indexOf(model.${field.name}';
              serializedRepresentation =
                  field.type.nullabilitySuffix == NullabilitySuffix.question
                  ? 'model.${field.name} == null ? null : $index!)'
                  : '$index)';
            } else if (const TypeChecker.typeNamed(Uint8List)
                .isAssignableFromType(type)) {
              var convert =
                  (field.type.nullabilitySuffix == NullabilitySuffix.question)
                  ? '!'
                  : '';

              serializedRepresentation =
                  '''
            model.${field.name} != null ?
              base64.encode(model.${field.name}$convert)
              : null
            ''';
            }
          }

          buf.write("${_dartLiteral(alias ?? '')}: $serializedRepresentation");
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

        // The parameters of the model's constructor that are not of a field,
        // which the map does not hold.
        for (var param in ctx.ownConstructorParameters) {
          (param.isNamed
                  ? method.optionalParameters
                  : method.requiredParameters)
              .add(_constructorParameter(ctx, param));
        }

        var buf = StringBuffer();

        // Required Fields
        ctx.requiredFields.forEach((key, msg) {
          if (ctx.excluded[key]?.canDeserialize == false) return;
          var name = _dartLiteral(ctx.resolveFieldName(key) ?? key);
          buf.writeln('''
            if (map[$name] == null) {
              throw FormatException(${_dartLiteral(msg)});
            }
          ''');
        });

        buf.writeln('return ${ctx.modelClassName}(');
        buf.write(_ownConstructorArguments(ctx));
        var i = 0;

        // Fields
        for (var field in ctx.fields) {
          var type = ctx.resolveSerializedFieldType(field.name ?? '');

          if (ctx.excluded[field.name]?.canDeserialize == false) continue;

          var alias = ctx.resolveFieldName(field.name ?? '');
          // The key, as a Dart string literal: an alias may hold `'` or `$`.
          var aliasLiteral = _dartLiteral(alias ?? '');

          if (i++ > 0) buf.write(', ');

          var deserializedRepresentation =
              "map[$aliasLiteral] as ${typeToString(type, ctx.clazz.library)}";

          if (type.nullabilitySuffix == NullabilitySuffix.question) {
            deserializedRepresentation += '?';
          }

          var defaultValue = 'null';
          var existingDefault = ctx.defaults[field.name];

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

          var fieldNameDeserializer = ctx.fieldInfo[field.name]?.deserializer;
          if (fieldNameDeserializer != null) {
            deserializedRepresentation =
                "$fieldNameDeserializer(map[$aliasLiteral])";
          } else if (dateTimeTypeChecker.isAssignableFromType(type)) {
            if (field.type.nullabilitySuffix != NullabilitySuffix.question) {
              if (defaultValue.toLowerCase() == 'null') {
                defaultValue = 'DateTime.parse("1970-01-01 00:00:00")';
              } else {
                defaultValue = 'DateTime.parse("$defaultValue")';
              }
            }
            deserializedRepresentation =
                "map[$aliasLiteral] != null ? "
                "(map[$aliasLiteral] is DateTime ? (map[$aliasLiteral] as DateTime) : DateTime.parse(map[$aliasLiteral].toString()))"
                ' : $defaultValue';
          }
          // Serialize model classes via `XSerializer.toMap`
          else if (isModelClass(type)) {
            var genClass = modelClassNameOf(type);
            var fromMap =
                "${genClass}Serializer.fromMap(map[$aliasLiteral] as Map)";
            // Without a default, a non-nullable model is required: a missing
            // one throws, as a missing `String` does, rather than give `null`.
            deserializedRepresentation =
                type.nullabilitySuffix != NullabilitySuffix.question &&
                    defaultValue == 'null'
                ? fromMap
                : "map[$aliasLiteral] != null ? $fromMap : $defaultValue";
          } else if (type is InterfaceType) {
            if (isListOfModelType(type)) {
              if (defaultValue == 'null') {
                defaultValue = '[]';
              }
              var genClass = modelClassNameOf(type.typeArguments[0]);

              deserializedRepresentation =
                  "map[$aliasLiteral] is Iterable"
                  " ? List.unmodifiable(((map[$aliasLiteral] as Iterable)"
                  '.whereType<Map>())'
                  '.map(${genClass}Serializer.fromMap))'
                  ' : $defaultValue';
            } else if (isMapToModelType(type)) {
              // TODO: This requires refractoring
              if (defaultValue == 'null') {
                defaultValue = '{}';
              }

              var genClass = modelClassNameOf(type.typeArguments[1]);
              deserializedRepresentation =
                  '''
                map[$aliasLiteral] is Map
                  ? Map.unmodifiable((map[$aliasLiteral] as Map).keys.fold({}, (out, key) {
                       return out..[key] = ${genClass}Serializer
                        .fromMap(((map[$aliasLiteral] as Map)[key]) as Map);
                    }))
                  : $defaultValue
            ''';
            } else if (type.element is EnumElement) {
              // An enum value, or its name or index, as a map from JSON or
              // from a service that stores enums as text has them.
              var enumType = typeToString(type, ctx.clazz.library);
              var fallback =
                  defaultValue == 'null' &&
                      type.nullabilitySuffix != NullabilitySuffix.question
                  ? "map[$aliasLiteral] as $enumType"
                  : defaultValue;
              deserializedRepresentation =
                  '''
            map[$aliasLiteral] is $enumType
              ? map[$aliasLiteral] as $enumType
              : map[$aliasLiteral] is String
              ? $enumType.values.byName(map[$aliasLiteral] as String)
              : map[$aliasLiteral] is int
              ? $enumType.values[map[$aliasLiteral] as int]
              : $fallback
            ''';

              //log.warning('Code => $deserializedRepresentation');
            } else if (const TypeChecker.typeNamed(List)
                    .isAssignableFromType(type) &&
                type.typeArguments.length == 1) {
              if (defaultValue == 'null') {
                defaultValue = '[]';
              }
              var arg = convertTypeReference(
                type.typeArguments[0],
                library: ctx.clazz.library,
              ).accept(DartEmitter(useNullSafetySyntax: true));
              deserializedRepresentation =
                  '''
                map[$aliasLiteral] is Iterable
                  ? (map[$aliasLiteral] as Iterable).cast<$arg>().toList()
                  : $defaultValue
                ''';
            } else if (const TypeChecker.typeNamed(Map)
                    .isAssignableFromType(type) &&
                type.typeArguments.length == 2) {
              var key = convertTypeReference(
                type.typeArguments[0],
                library: ctx.clazz.library,
              ).accept(DartEmitter(useNullSafetySyntax: true));
              var value = convertTypeReference(
                type.typeArguments[1],
                library: ctx.clazz.library,
              ).accept(DartEmitter(useNullSafetySyntax: true));

              if (defaultValue == 'null') {
                defaultValue = '{}';
              }
              deserializedRepresentation =
                  '''
                map[$aliasLiteral] is Map
                  ? (map[$aliasLiteral] as Map).cast<$key, $value>()
                  : $defaultValue
                ''';
            } else if (const TypeChecker.typeNamed(Uint8List)
                .isAssignableFromType(type)) {
              deserializedRepresentation =
                  '''
            map[$aliasLiteral] is Uint8List
              ? (map[$aliasLiteral] as Uint8List)
              :
              (
                map[$aliasLiteral] is Iterable<int>
                  ? Uint8List.fromList((map[$aliasLiteral] as Iterable<int>).toList())
                  :
                  (
                    map[$aliasLiteral] is String
                      ? Uint8List.fromList(base64.decode(map[$aliasLiteral] as String))
                      : $defaultValue
                  )
              )
            ''';
            }
          }

          buf.write('${field.name}: $deserializedRepresentation');
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
                ctx.fields.map((f) => refer(f.name ?? '')).toList(),
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
                ..name = field.name
                ..assignment = Code(
                  _dartLiteral(ctx.resolveFieldName(field.name ?? '') ?? ''),
                );
            }),
          );
        }
      }),
    );
  }
}
