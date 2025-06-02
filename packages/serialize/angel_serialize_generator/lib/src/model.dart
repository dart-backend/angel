part of 'serialize_generator.dart';

class JsonModelGenerator extends GeneratorForAnnotation<Serializable> {
  const JsonModelGenerator();

  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    if (element.kind != ElementKind.CLASS) {
      throw 'Only classes can be annotated with a @Serializable() annotation.';
    }

    var ctx = await buildContext(element as ClassElement, annotation, buildStep,
        buildStep.resolver, true);

    if (ctx == null) {
      log.fine('Invalid builder context');
      throw 'Invalid builder context';
    }

    var lib = Library((b) {
      generateClass(ctx, b, annotation);
    });

    var buf = lib.accept(DartEmitter(useNullSafetySyntax: true));
    return buf.toString();
  }

  /// Generate an extended model class.
  void generateClass(
      BuildContext ctx, LibraryBuilder file, ConstantReader annotation) {
    file.body.add(Class((clazz) {
      //log.fine('Generate Class: ${ctx.modelClassNameRecase.pascalCase}');
      clazz
        ..name = ctx.modelClassNameRecase.pascalCase
        ..annotations.add(refer('generatedSerializable'));

      for (var ann in ctx.includeAnnotations) {
        clazz.annotations.add(convertObject(ann));
      }

      if (shouldBeConstant(ctx)) {
        clazz.implements.add(Reference(ctx.originalClassName));
      } else {
        clazz.extend = Reference(ctx.originalClassName);
      }

      //if (ctx.importsPackageMeta)
      //  clazz.annotations.add(CodeExpression(Code('immutable')));

      // Generate the fields for the class
      for (var field in ctx.fields) {
        //log.fine('Generate Field: ${field.name}');

        clazz.fields.add(Field((b) {
          b
            ..name = field.name
            //..modifier = FieldModifier.final$
            //..annotations.add(CodeExpression(Code('override')))
            ..annotations.add(refer('override'))
            ..type = convertTypeReference(field.type);

          // Fields should only be forced-final if the original field has no setter.
          //log.fine('Final: ${field.isFinal}');
          //if (field.setter == null && field is! ShimFieldImpl) {
          //if (field.isFinal) {
          //  b.modifier = FieldModifier.final$;
          //}

          for (var el in [field.getter, field]) {
            //if (el?.documentationComment != null) {
            b.docs.addAll(el?.documentationComment?.split('\n') ?? []);
            //}
          }
        }));
      }

      generateConstructor(ctx, clazz, file);
      generateCopyWithMethod(ctx, clazz, file);
      generateEqualsOperator(ctx, clazz, file);
      generateHashCode(ctx, clazz);
      generateToString(ctx, clazz);

      // Generate toJson() method if necessary
      var serializers = annotation.peek('serializers')?.listValue ?? [];

      if (serializers.any((o) => o.toIntValue() == Serializers.json)) {
        clazz.methods.add(Method((method) {
          method
            ..name = 'toJson'
            ..returns = Reference('Map<String, dynamic>')
            ..body = Code('return ${clazz.name}Serializer.toMap(this);');
        }));
      }
    }));
  }

  bool shouldBeConstant(BuildContext ctx) {
    // Check if all fields are without a getter
    return !isAssignableToModel(ctx.clazz.thisType) &&
        ctx.clazz.fields.every((f) =>
            f.getter?.isAbstract != false && f.setter?.isAbstract != false);
  }

  /// Generate a constructor with named parameters.
  void generateConstructor(
      BuildContext ctx, ClassBuilder clazz, LibraryBuilder file) {
    clazz.constructors.add(Constructor((constructor) {
      // Add all `super` params
      //constructor.constant = (ctx.clazz.unnamedConstructor?.isConst == true ||
      //        shouldBeConstant(ctx)) &&
      //    ctx.fields.every((f) {
      //      return f.setter == null && f is! ShimFieldImpl;
      //    });

      for (var param in ctx.constructorParameters) {
        //log.fine('Contructor Parameter: ${param.name}');
        constructor.requiredParameters.add(Parameter((b) => b
          ..name = param.name
          ..type = convertTypeReference(param.type)));
      }

      // Generate intializers
      for (var field in ctx.fields) {
        if (!shouldBeConstant(ctx) && isListOrMapType(field.type)) {
          var typeName = const TypeChecker.fromRuntime(List)
                  .isAssignableFromType(field.type)
              ? 'List'
              : 'Map';
          String? defaultValue = typeName == 'List' ? '[]' : '{}';

          var existingDefault = ctx.defaults[field.name];
          if (existingDefault != null) {
            defaultValue = dartObjectToString(existingDefault);
          }

          if (field.type.nullabilitySuffix != NullabilitySuffix.question) {
            constructor.initializers.add(Code('''
              ${field.name} =
                $typeName.unmodifiable(${field.name})'''));
          } else {
            constructor.initializers.add(Code('''
              ${field.name} =
                $typeName.unmodifiable(${field.name} ?? $defaultValue)'''));
          }
        }
      }

      // Generate the parameters for the constructor
      for (var field in ctx.fields) {
        //log.fine('Contructor Field: ${field.name}');

        constructor.optionalParameters.add(Parameter((b) {
          b
            ..toThis = shouldBeConstant(ctx)
            ..name = field.name
            ..named = true;

          var existingDefault = ctx.defaults[field.name];

          if (existingDefault != null) {
            var d = dartObjectToString(existingDefault);
            if (d != null) {
              b.defaultTo = Code(d);
            }
          }

          //log.fine(
          //    'Constructor => ${field.name} ${field.type.nullabilitySuffix}');
          if (!isListOrMapType(field.type)) {
            b.toThis = true;
          } else if (isListType(field.type)) {
            if (!b.toThis) {
              b.type = convertTypeReference(field.type);
            }

            // Get the default if presence
            var existingDefault = ctx.defaults[field.name];
            if (existingDefault != null) {
              var defaultValue = dartObjectToString(existingDefault);
              b.defaultTo = Code('$defaultValue');
            } else {
              b.defaultTo = Code('const []');
            }
          } else if (!b.toThis) {
            b.type = convertTypeReference(field.type);
          } else {
            log.fine('Contructor: ${field.name} pass through');
          }

          if ((ctx.requiredFields.containsKey(field.name) ||
                  field.type.nullabilitySuffix != NullabilitySuffix.question) &&
              b.defaultTo == null) {
            //b.annotations.add(CodeExpression(Code('required')));
            b.required = true;
          }
        }));
      }

      if (ctx.constructorParameters.isNotEmpty) {
        if (!shouldBeConstant(ctx) ||
            ctx.clazz.unnamedConstructor?.isConst == true) {
          constructor.initializers.add(Code(
              'super(${ctx.constructorParameters.map((p) => p.name).join(',')})'));
        }
      }
    }));
  }

  /// Generate a `copyWith` method.
  void generateCopyWithMethod(
      BuildContext ctx, ClassBuilder clazz, LibraryBuilder file) {
    clazz.methods.add(Method((method) {
      method
        ..name = 'copyWith'
        ..returns = ctx.modelClassType;

      // Add all `super` params
      if (ctx.constructorParameters.isNotEmpty) {
        for (var param in ctx.constructorParameters) {
          method.requiredParameters.add(Parameter((b) => b
            ..name = param.name
            ..type = convertTypeReference(param.type)));
        }
      }

      var buf = StringBuffer('return ${ctx.modelClassName}(');
      var i = 0;
      for (var param in ctx.constructorParameters) {
        if (i++ > 0) buf.write(', ');
        buf.write(param.name);
      }

      // Add named parameters
      for (var field in ctx.fields) {
        method.optionalParameters.add(Parameter((b) {
          b
            ..name = field.name
            ..named = true
            ..type = convertTypeReference(field.type, forceNullable: true);
        }));

        if (i++ > 0) buf.write(', ');
        buf.write('${field.name}: ${field.name} ?? this.${field.name}');
      }

      buf.write(');');
      method.body = Code(buf.toString());
    }));
  }

  static String? generateEquality(DartType type, [bool nullable = false]) {
    if (type is InterfaceType) {
      if (const TypeChecker.fromRuntime(List).isAssignableFromType(type)) {
        if (type.typeArguments.length == 1) {
          var eq = generateEquality(type.typeArguments[0]);
          return 'ListEquality<${type.typeArguments[0].element!.name}>($eq)';
        } else {
          return 'ListEquality()';
        }
      } else if (const TypeChecker.fromRuntime(Map)
          .isAssignableFromType(type)) {
        if (type.typeArguments.length == 2) {
          var keq = generateEquality(type.typeArguments[0]),
              veq = generateEquality(type.typeArguments[1]);
          return 'MapEquality<${type.typeArguments[0].element!.name}, ${type.typeArguments[1].element!.name}>(keys: $keq, values: $veq)';
        } else {
          return 'MapEquality()';
        }
      }

      return nullable ? null : 'DefaultEquality<${type.element.name}>()';
    } else {
      return 'DefaultEquality()';
    }
  }

  static String Function(String, String) generateComparator(DartType type) {
    if (type is! InterfaceType || type.element.displayName == 'dynamic') {
      return (a, b) => '$a == $b';
    }
    var eq = generateEquality(type, true);
    if (eq == null) return (a, b) => '$a == $b';
    return (a, b) => '$eq.equals($a, $b)';
  }

  void generateHashCode(BuildContext? ctx, ClassBuilder clazz) {
    clazz.methods.add(Method((method) {
      method
        ..name = 'hashCode'
        ..type = MethodType.getter
        ..returns = refer('int')
        ..annotations.add(refer('override'))
        ..body = refer('hashObjects')
            .call([literalList(ctx!.fields.map((f) => refer(f.name)))])
            .returned
            .statement;
    }));
  }

  void generateToString(BuildContext? ctx, ClassBuilder clazz) {
    clazz.methods.add(Method((b) {
      b
        ..name = 'toString'
        ..returns = refer('String')
        ..annotations.add(refer('override'))
        ..body = Block((b) {
          var buf = StringBuffer('\'${ctx!.modelClassName}(');
          var i = 0;
          for (var field in ctx.fields) {
            if (i++ > 0) buf.write(', ');
            buf.write('${field.name}=\$${field.name}');
          }
          buf.write(')\'');
          b.addExpression(CodeExpression(Code(buf.toString())).returned);
        });
    }));
  }

  void generateEqualsOperator(
      BuildContext? ctx, ClassBuilder clazz, LibraryBuilder file) {
    clazz.methods.add(Method((method) {
      method
        ..name = 'operator =='
        ..annotations.add(refer('override'))
        ..returns = Reference('bool')
        ..requiredParameters.add(Parameter((b) => b.name = 'other'));

      var buf = ['other is ${ctx!.originalClassName}'];

      buf.addAll(ctx.fields.map((f) {
        return generateComparator(f.type)('other.${f.name}', f.name);
      }));

      method.body = Code('return ${buf.join('&&')};');
    }));
  }
}
