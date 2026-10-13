import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_container/angel3_container.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

/// Generates, for a library with `@injectable` classes, one [ReflectionData]
/// variable describing how to construct them, named after the file (e.g.
/// `servicesReflection` for `services.dart`).
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
    var classes = [
      for (var annotated in library.annotatedWith(_injectable))
        _checkClass(annotated.element),
    ];
    if (classes.isEmpty) return null;

    var out = StringBuffer()
      ..writeln(
        '/// How to construct the `@injectable` classes of this library; pass '
        'it to [StaticReflector.combine].',
      )
      ..writeln(
        'final ${reflectionVariableName(buildStep.inputId.path)} = '
        'ReflectionData(types: {',
      );
    for (var clazz in classes) {
      out.writeln('  ${clazz.name}: ${await _describe(clazz, buildStep)},');
    }
    out
      ..writeln('});')
      ..writeln()
      ..writeln('Type _\$typeOf<T>() => T;');
    if (out.toString().contains('_\$named(')) {
      out
        ..writeln()
        ..writeln('/// The named arguments in [n] that the constructor takes.')
        ..writeln(
          'Map<Symbol, dynamic> _\$named(Map<String, dynamic> n, '
          'Map<String, Symbol> symbols) => '
          '{for (var e in n.entries) if (symbols[e.key] case var s?) s: e.value};',
        );
    }
    return out.toString();
  }

  ClassElement _checkClass(Element element) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@injectable can only be applied to classes.',
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
    var constructor = clazz.unnamedConstructor;
    if (constructor == null ||
        constructor.isPrivate ||
        (clazz.isAbstract && !constructor.isFactory)) {
      // Described, but cannot be constructed.
      return "StaticReflectedClass('${_escape(name)}', $name)";
    }

    var parameters = <String>[];
    var positional = <String>[];
    var named = <String>[];
    var symbols = <String>[];
    var hasOptional = false;
    for (var parameter in constructor.formalParameters) {
      var paramName = parameter.name!;
      var key = "'${_escape(paramName)}'";
      var type = await _typeSource(parameter, buildStep);
      var isRequired =
          parameter.isRequiredPositional || parameter.isRequiredNamed;
      parameters.add(
        'ReflectedParameter($key, const [], '
        "StaticReflectedType('${_escape(type)}', _\$typeOf<$type>()), "
        '$isRequired, ${parameter.isNamed}, '
        'hasDefaultValue: ${parameter.hasDefaultValue})',
      );

      if (!isRequired) hasOptional = true;
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
    var create = hasOptional
        ? 'Function.apply($name.new, p'
              '${symbols.isEmpty ? '' : ', _\$named(n, const {${symbols.join(', ')}})'})'
        : '$name(${[...positional, ...named].join(', ')})';

    return "StaticReflectedClass('${_escape(name)}', $name, "
        'parameters: [${parameters.join(', ')}], '
        'create: (p, n) => $create)';
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
