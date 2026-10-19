import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_container/angel3_container.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

/// Generates, for a library with `@injectable` classes or top-level
/// functions, one [ReflectionData] variable describing them, named after the
/// file (e.g. `servicesReflection` for `services.dart`).
///
/// For a class, that is how to construct it, its annotations, and its public
/// instance methods (with their parameters and annotations, and how to read
/// them from an instance); for a function, its parameters and annotations.
///
/// The generated code calls each class's unnamed constructor without
/// `dart:mirrors`: directly, or with `Function.apply` and symbol literals when
/// it has optional parameters, so that their defaults apply.
class StaticReflectionGenerator extends Generator {
  static const _injectable = TypeChecker.typeNamed(
    Injectable,
    inPackage: 'angel3_container',
  );

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    var classes = <ClassElement>[];
    var functions = <TopLevelFunctionElement>[];
    for (var annotated in library.annotatedWith(_injectable)) {
      switch (_check(annotated.element)) {
        case ClassElement clazz:
          classes.add(clazz);
        case TopLevelFunctionElement function:
          functions.add(function);
      }
    }
    if (classes.isEmpty && functions.isEmpty) return null;

    var out = StringBuffer()
      ..writeln(
        '/// How to construct, and reflect upon, the `@injectable` classes and '
        'functions of this library; pass it to [StaticReflector.combine].',
      )
      ..writeln(
        'final ${reflectionVariableName(buildStep.inputId.path)} = '
        'ReflectionData(',
      );
    if (classes.isNotEmpty) {
      out.writeln('types: {');
      for (var clazz in classes) {
        out.writeln('  ${clazz.name}: ${await _describe(clazz, buildStep)},');
      }
      out.writeln('},');
    }
    if (functions.isNotEmpty) {
      out.writeln('functions: {');
      for (var function in functions) {
        out.writeln(
          '  ${function.name}: '
          '${await _function(function, function.formalParameters, buildStep)},',
        );
      }
      out.writeln('},');
    }
    out
      ..writeln(');')
      ..writeln()
      ..writeln('Type _\$typeOf<T>() => T;');
    if (out.toString().contains('_\$named(')) {
      out
        ..writeln()
        ..writeln('/// The named arguments in [n] that the constructor takes.')
        ..writeln(
          'Map<Symbol, dynamic> _\$named(Map<String, dynamic> n, '
          'Map<String, Symbol> symbols) => '
          '{for (var e in n.entries) ?symbols[e.key]: e.value};',
        );
    }
    return out.toString();
  }

  Element _check(Element element) {
    if (element is TopLevelFunctionElement) {
      if (element.typeParameters.isNotEmpty) {
        throw InvalidGenerationSourceError(
          '@injectable does not support generic functions.',
          element: element,
        );
      }
      return element;
    }
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@injectable can only be applied to classes and top-level functions.',
        element: element,
      );
    }
    if (element.typeParameters.isNotEmpty) {
      throw InvalidGenerationSourceError(
        '@injectable does not support generic classes: the container makes '
        'instances by their exact type, such as `${element.name}<int>`, which '
        'cannot be listed in advance.',
        element: element,
      );
    }
    if (element.isPrivate) {
      throw InvalidGenerationSourceError(
        '@injectable does not support private classes.',
        element: element,
      );
    }
    return element;
  }

  Future<String> _describe(ClassElement clazz, BuildStep buildStep) async {
    var name = clazz.name!;
    var fields = <String>["'${_escape(name)}'", name];

    var constructor = clazz.unnamedConstructor;
    // An abstract class without a factory constructor cannot be constructed.
    if (constructor != null &&
        !constructor.isPrivate &&
        !(clazz.isAbstract && !constructor.isFactory)) {
      fields
        ..add(
          'parameters: '
          '${await _parameters(constructor.formalParameters, buildStep)}',
        )
        ..add('create: (p, n) => ${_create(name, constructor)}');
    }

    var annotations = await _annotations(clazz, buildStep);
    if (annotations != '[]') fields.add('annotations: $annotations');

    // The public instance methods declared in the class, which e.g. `@Expose`
    // controllers route to.
    var methods = [
      for (var method in clazz.methods)
        if (!method.isStatic && !method.isPrivate && !method.isOperator) method,
    ];
    if (methods.isNotEmpty) {
      var described = [
        for (var method in methods)
          await _function(method, method.formalParameters, buildStep),
      ];
      fields.add('methods: [${described.join(', ')}]');
    }

    // The public instance members, declared or inherited, by name: those of
    // the methods as tear-offs, and the fields and getters as their values,
    // which e.g. a template reads.
    var members = _members(clazz);
    if (members.isNotEmpty) {
      var cases = [
        for (var member in members)
          "'${_escape(member)}' => (o as $name).$member",
      ];
      fields.add(
        'getMember: (o, name) => switch (name) '
        '{${cases.join(', ')}, _ => noStaticMember}',
      );
    }

    return 'StaticReflectedClass(${fields.join(', ')})';
  }

  /// The names of the public instance fields, getters and methods of
  /// [clazz], and of its supertypes but `Object`, which `getMember` reads.
  static List<String> _members(ClassElement clazz) {
    var names = <String>{};
    for (var type in [clazz, ...clazz.allSupertypes.map((t) => t.element)]) {
      if (type is ClassElement && type.isDartCoreObject) continue;
      for (var getter in type.getters) {
        if (!getter.isStatic && !getter.isPrivate) names.add(getter.name!);
      }
      for (var method in type.methods) {
        if (!method.isStatic && !method.isPrivate && !method.isOperator) {
          names.add(method.name!);
        }
      }
    }
    return [...names];
  }

  /// A call to [constructor] of the class [name] with the arguments the
  /// container passes: `p` (positional) and `n` (named).
  String _create(String name, ConstructorElement constructor) {
    var positional = <String>[];
    var named = <String>[];
    var symbols = <String>[];
    var hasOptional = false;
    for (var parameter in constructor.formalParameters) {
      var paramName = parameter.name!;
      var key = "'${_escape(paramName)}'";
      if (!(parameter.isRequiredPositional || parameter.isRequiredNamed)) {
        hasOptional = true;
      }
      if (parameter.isNamed) {
        named.add('$paramName: n[$key]');
        symbols.add('$key: #$paramName');
      } else {
        positional.add('p[${positional.length}]');
      }
    }

    // With only required parameters, the constructor is called directly.
    // Otherwise only the arguments the container passes are given, through
    // Function.apply, so that Dart applies each left-out parameter's default
    // (including one inherited by a `super.` parameter). Symbol literals,
    // unlike `Symbol('name')`, are renamed with the code when it is
    // obfuscated.
    return hasOptional
        ? 'Function.apply($name.new, p'
              '${symbols.isEmpty ? '' : ', _\$named(n, const {${symbols.join(', ')}})'})'
        : '$name(${[...positional, ...named].join(', ')})';
  }

  /// A `StaticReflectedFunction` describing [function].
  Future<String> _function(
    Element function,
    List<FormalParameterElement> parameters,
    BuildStep buildStep,
  ) async {
    var annotations = await _annotations(function, buildStep);
    return "StaticReflectedFunction('${_escape(function.name!)}', "
        '${await _parameters(parameters, buildStep)}'
        '${annotations == '[]' ? '' : ', annotations: $annotations'})';
  }

  Future<String> _parameters(
    List<FormalParameterElement> parameters,
    BuildStep buildStep,
  ) async {
    var described = <String>[];
    for (var parameter in parameters) {
      var type = await _typeSource(parameter, buildStep);
      var annotations = await _annotations(parameter, buildStep);
      described.add(
        "StaticReflectedParameter('${_escape(parameter.name!)}', "
        "StaticReflectedType('${_escape(type)}', _\$typeOf<$type>()), "
        'isRequired: '
        '${parameter.isRequiredPositional || parameter.isRequiredNamed}, '
        'isNamed: ${parameter.isNamed}, '
        'hasDefaultValue: ${parameter.hasDefaultValue}'
        '${annotations == '[]' ? '' : ', annotations: $annotations'})',
      );
    }
    return '[${described.join(', ')}]';
  }

  /// [element]'s annotations (except `@override`), as a list of expressions
  /// that are valid in the generated part: a static member of a class that
  /// an annotation names without its class is qualified with it.
  Future<String> _annotations(Element element, BuildStep buildStep) async {
    var node = await buildStep.resolver.astNodeFor(
      element.firstFragment,
      resolve: true,
    );
    var metadata = switch (node) {
      AnnotatedNode(:var metadata) => metadata,
      _ => const <Annotation>[],
    };
    var expressions = <String>[];
    for (var annotation in metadata) {
      var source = _qualifiedSource(annotation);
      if (source == 'override') continue;
      expressions.add(source);
    }
    return '[${expressions.join(', ')}]';
  }

  /// The annotation as an expression: its constant, or a `const` constructor
  /// call.
  static String _qualifiedSource(Annotation annotation) {
    // Without the leading `@`.
    var source = _qualifyStatics(
      annotation,
      annotation.toSource(),
    ).substring(1);
    return annotation.arguments == null ? source : 'const $source';
  }

  /// [source] (the source of [node]) with every static class member it names
  /// without its class (as is allowed inside the class) qualified with it.
  static String _qualifyStatics(AstNode node, String source) {
    var finder = _StaticReferences();
    node.accept(finder);
    var result = source;
    // From the end, so the offsets of earlier references stay valid.
    for (var (offset, qualifier) in finder.references.reversed) {
      var at = offset - node.offset;
      result = '${result.substring(0, at)}$qualifier.${result.substring(at)}';
    }
    return result;
  }

  /// The parameter's type, without a trailing `?`, as written in the source
  /// (so that import prefixes are kept); the container looks values up by
  /// their non-nullable type.
  Future<String> _typeSource(
    FormalParameterElement parameter,
    BuildStep buildStep,
  ) async {
    var node = await buildStep.resolver.astNodeFor(parameter.firstFragment);
    // For a function-typed parameter (`int f(String s)`), `type` is only the
    // return type.
    var annotation = node is FormalParameter && node.functionTypedSuffix == null
        ? node.type
        : null;
    if (annotation != null) {
      var source = annotation.toSource();
      return annotation.question != null
          ? source.substring(0, source.length - 1)
          : source;
    }

    // `this.x`, `super.x` or a function-typed parameter: print the type the
    // analyzer inferred, with the import prefixes this library uses.
    var library = parameter.library!;
    return _typeName(
      library.typeSystem.promoteToNonNull(parameter.type),
      library,
      parameter,
    );
  }

  /// [type] as it can be written in [library]. Throws when a type in it is
  /// not in scope there, e.g. one that only a superclass's library imports.
  static String _typeName(
    DartType type,
    LibraryElement library,
    Element parameter,
  ) {
    String name(DartType t) => _typeName(t, library, parameter);
    var question = type.nullabilitySuffix == NullabilitySuffix.question
        ? '?'
        : '';

    var alias = type.alias;
    if (alias != null) {
      var args = alias.typeArguments;
      return '${_qualified(alias.element, library, parameter)}'
          '${args.isEmpty ? '' : '<${args.map(name).join(', ')}>'}$question';
    }

    switch (type) {
      case InterfaceType():
        var args = type.typeArguments;
        return '${_qualified(type.element, library, parameter)}'
            '${args.isEmpty ? '' : '<${args.map(name).join(', ')}>'}$question';
      case FunctionType() when type.typeParameters.isEmpty:
        var required = [
          for (var p in type.formalParameters)
            if (p.isRequiredPositional) name(p.type),
        ];
        var optional = [
          for (var p in type.formalParameters)
            if (p.isOptionalPositional) name(p.type),
        ];
        var named = [
          for (var p in type.formalParameters)
            if (p.isNamed)
              '${p.isRequiredNamed ? 'required ' : ''}${name(p.type)} ${p.name}',
        ];
        var params = [
          ...required,
          if (optional.isNotEmpty) '[${optional.join(', ')}]',
          if (named.isNotEmpty) '{${named.join(', ')}}',
        ].join(', ');
        var function = '${name(type.returnType)} Function($params)';
        return question.isEmpty ? function : '($function)?';
      case RecordType():
        var positional = type.positionalFields.map((f) => name(f.type));
        var named = type.namedFields.map((f) => '${name(f.type)} ${f.name}');
        var fields = [
          ...positional,
          if (named.isNotEmpty) '{${named.join(', ')}}',
        ];
        // A record with one positional field needs a trailing comma.
        var trailing = fields.length == 1 && named.isEmpty ? ',' : '';
        return '(${fields.join(', ')}$trailing)$question';
      case DynamicType() || VoidType() || NeverType():
        return type.getDisplayString();
      default:
        throw InvalidGenerationSourceError(
          'The type of this parameter, ${type.getDisplayString()}, cannot be '
          'written in this library; declare its type explicitly.',
          element: parameter,
        );
    }
  }

  /// [element]'s name as it can be written in [library], with the prefix
  /// [library] imports it with, if any.
  static String _qualified(
    Element element,
    LibraryElement library,
    Element parameter,
  ) {
    var name = element.name!;
    if (element.library == library) return name;
    String? prefix;
    for (var fragment in library.fragments) {
      for (var import in fragment.libraryImports) {
        // Takes `show` and `hide` into account.
        if (import.namespace.definedNames2[name] != element) continue;
        var importPrefix = import.prefix?.element.name;
        if (importPrefix == null) return name;
        prefix ??= importPrefix;
      }
    }
    if (prefix == null) {
      throw InvalidGenerationSourceError(
        '$name, in the type of this parameter, is not imported by this '
        'library, so the generated code cannot name it. Import it, or declare '
        "the parameter's type explicitly.",
        element: parameter,
      );
    }
    return '$prefix.$name';
  }

  static String _escape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
}

/// The name of the variable generated for the library at [path]: its file
/// name in lowerCamelCase, followed by `Reflection` (`$` first when the name
/// starts with a digit, and just `reflection` when it has no letters or
/// digits).
String reflectionVariableName(String path) {
  var words = p
      .basenameWithoutExtension(path)
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'reflection';
  var camel = [
    words.first.toLowerCase(),
    for (var w in words.skip(1)) w[0].toUpperCase() + w.substring(1),
  ].join();
  // An identifier cannot start with a digit; `_` would make it private.
  var start = camel.codeUnitAt(0);
  if (start >= 0x30 && start <= 0x39) camel = '\$$camel';
  return '${camel}Reflection';
}

/// Finds the static class members a node names without their class, with the
/// class name to qualify each with.
class _StaticReferences extends RecursiveAstVisitor<void> {
  final references = <(int, String)>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.element;
    var enclosing = element?.enclosingElement;
    var isStatic = switch (element) {
      ExecutableElement(:var isStatic) => isStatic,
      FieldElement(:var isStatic) => isStatic,
      _ => false,
    };
    var parent = node.parent;
    var isQualified =
        (parent is PrefixedIdentifier && parent.identifier == node) ||
        (parent is PropertyAccess && parent.propertyName == node) ||
        (parent is MethodInvocation &&
            parent.methodName == node &&
            parent.target != null);
    if (isStatic && enclosing is InterfaceElement && !isQualified) {
      references.add((node.offset, enclosing.name!));
    }
    super.visitSimpleIdentifier(node);
  }
}
