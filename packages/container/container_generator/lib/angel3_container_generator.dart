import 'package:angel3_container/angel3_container.dart';
import 'package:reflectable/reflectable.dart';

/// A [Reflectable] instance that can be used as an annotation on types to generate metadata for them.
const Reflectable contained = ContainedReflectable();

@contained
class ContainedReflectable extends Reflectable {
  const ContainedReflectable()
    : super(
        topLevelInvokeCapability,
        typeAnnotationQuantifyCapability,
        superclassQuantifyCapability,
        libraryCapability,
        invokingCapability,
        metadataCapability,
        reflectedTypeCapability,
        typeCapability,
        typingCapability,
      );
}

/// A [Reflector] instance that uses a [Reflectable] to reflect upon data.
class GeneratedReflector extends Reflector {
  final Reflectable reflectable;

  const GeneratedReflector([this.reflectable = contained]);

  @override
  String getName(Symbol symbol) =>
      const EmptyReflector().getName(symbol) ?? symbol.toString();

  @override
  ReflectedClass reflectClass(Type clazz) {
    return reflectType(clazz) as ReflectedClass;
  }

  @override
  ReflectedFunction reflectFunction(Function function) {
    if (!reflectable.canReflect(function)) {
      throw UnsupportedError('Cannot reflect $function.');
    }

    var mirror = reflectable.reflect(function);

    if (mirror is ClosureMirror) {
      return _GeneratedReflectedFunction(mirror.function, this, mirror);
    } else {
      throw ArgumentError('$function is not a Function.');
    }
  }

  @override
  ReflectedInstance reflectInstance(Object object) {
    if (!reflectable.canReflect(object)) {
      throw UnsupportedError('Cannot reflect $object.');
    } else {
      var mirror = reflectable.reflect(object);
      return _GeneratedReflectedInstance(mirror, this);
    }
  }

  /// Reflects [value], or wraps it if [reflectable] cannot reflect it (e.g.
  /// `null`, or a method tear-off).
  ReflectedInstance _reflectValue(Object? value) =>
      value != null && reflectable.canReflect(value)
      ? _GeneratedReflectedInstance(reflectable.reflect(value), this)
      : _ValueReflectedInstance(value);

  /// Like [reflectType], but describes a type [reflectable] cannot reflect
  /// (e.g. a parameter's type) instead of throwing.
  ReflectedType _reflectTypeOrDescribe(Type type) =>
      reflectable.canReflectType(type)
      ? reflectType(type)
      : _ValueReflectedClass(type);

  @override
  ReflectedType reflectType(Type type) {
    if (!reflectable.canReflectType(type)) {
      throw UnsupportedError('Cannot reflect $type.');
    } else {
      var mirror = reflectable.reflectType(type);
      return mirror is ClassMirror
          ? _GeneratedReflectedClass(mirror, this)
          : _GeneratedReflectedType(mirror);
    }
  }
}

class _GeneratedReflectedInstance extends ReflectedInstance {
  final InstanceMirror mirror;
  final GeneratedReflector reflector;

  _GeneratedReflectedInstance(this.mirror, this.reflector)
    : super(
        _GeneratedReflectedType(mirror.type),
        _GeneratedReflectedClass(mirror.type, reflector),
        mirror.reflectee,
      );

  @override
  ReflectedType get type => clazz;

  @override
  ReflectedInstance getField(String name) =>
      reflector._reflectValue(mirror.invokeGetter(name));
}

class _GeneratedReflectedClass extends ReflectedClass {
  final ClassMirror mirror;
  final Reflector reflector;

  _GeneratedReflectedClass(this.mirror, this.reflector)
    : super(mirror.simpleName, [], [], [], [], mirror.reflectedType);

  @override
  List<ReflectedTypeParameter> get typeParameters =>
      mirror.typeVariables.map(_convertTypeVariable).toList();

  @override
  List<ReflectedFunction> get constructors =>
      _constructorsOf(mirror.declarations, reflector);

  @override
  List<ReflectedDeclaration> get declarations =>
      _declarationsOf(mirror.declarations, reflector);

  @override
  List<ReflectedInstance> get annotations => mirror.metadata
      .map(reflector.reflectInstance)
      .whereType<ReflectedInstance>()
      .toList();

  @override
  bool isAssignableTo(ReflectedType? other) {
    if (other is _GeneratedReflectedClass) {
      return mirror.isAssignableTo(other.mirror);
    } else if (other is _GeneratedReflectedType) {
      return mirror.isAssignableTo(other.mirror);
    } else {
      return false;
    }
  }

  @override
  ReflectedInstance newInstance(
    String constructorName,
    List positionalArguments, [
    Map<String, dynamic>? namedArguments,
    List<Type>? typeArguments,
  ]) {
    namedArguments ??= {};
    var result = mirror.newInstance(
      constructorName,
      positionalArguments,
      namedArguments.map((k, v) => MapEntry(Symbol(k), v)),
    );
    return reflector.reflectInstance(result)!;
  }
}

class _GeneratedReflectedType extends ReflectedType {
  final TypeMirror mirror;

  _GeneratedReflectedType(this.mirror)
    : super(mirror.simpleName, [], mirror.reflectedType);

  @override
  List<ReflectedTypeParameter> get typeParameters =>
      mirror.typeVariables.map(_convertTypeVariable).toList();

  @override
  bool isAssignableTo(ReflectedType? other) {
    if (other is _GeneratedReflectedClass) {
      return mirror.isAssignableTo(other.mirror);
    } else if (other is _GeneratedReflectedType) {
      return mirror.isAssignableTo(other.mirror);
    } else {
      return false;
    }
  }

  @override
  ReflectedInstance newInstance(
    String constructorName,
    List positionalArguments, [
    Map<String, dynamic> namedArguments = const {},
    List<Type> typeArguments = const [],
  ]) {
    throw UnsupportedError('Cannot create a new instance of $reflectedType.');
  }
}

class _GeneratedReflectedFunction extends ReflectedFunction {
  final MethodMirror mirror;
  final Reflector reflector;
  final ClosureMirror? closure;

  _GeneratedReflectedFunction(this.mirror, this.reflector, [this.closure])
    : super(
        mirror.simpleName,
        [],
        [],
        mirror.parameters.map((p) => _convertParameter(p, reflector)).toList(),
        mirror.isGetter,
        mirror.isSetter,
        returnType: !mirror.isRegularMethod
            ? null
            : _GeneratedReflectedType(mirror.returnType),
      );

  @override
  List<ReflectedInstance> get annotations => mirror.metadata
      .map(reflector.reflectInstance)
      .whereType<ReflectedInstance>()
      .toList();

  @override
  ReflectedInstance invoke(Invocation invocation) {
    var closure = this.closure;
    if (closure == null) {
      throw UnsupportedError('Only closures can be invoked directly.');
    }
    var result = closure.delegate(invocation);
    var reflector = this.reflector;
    return reflector is GeneratedReflector
        ? reflector._reflectValue(result)
        : reflector.reflectInstance(result!)!;
  }
}

List<ReflectedFunction> _constructorsOf(
  Map<String, DeclarationMirror> map,
  Reflector reflector,
) {
  return map.entries.fold<List<ReflectedFunction>>([], (out, entry) {
    var v = entry.value;

    if (v is MethodMirror && v.isConstructor) {
      return out..add(_GeneratedReflectedFunction(v, reflector));
    } else {
      return out;
    }
  });
}

List<ReflectedDeclaration> _declarationsOf(
  Map<String, DeclarationMirror> map,
  Reflector reflector,
) {
  return map.entries.fold<List<ReflectedDeclaration>>([], (out, entry) {
    var v = entry.value;

    // Like MirrorsReflector: methods (including getters and setters) only,
    // so every declaration has a function.
    if (v is MethodMirror && !v.isConstructor) {
      var decl = ReflectedDeclaration(
        v.simpleName,
        v.isStatic,
        _GeneratedReflectedFunction(v, reflector),
      );
      return out..add(decl);
    } else {
      return out;
    }
  });
}

ReflectedTypeParameter _convertTypeVariable(TypeVariableMirror mirror) {
  return ReflectedTypeParameter(mirror.simpleName);
}

ReflectedParameter _convertParameter(
  ParameterMirror mirror,
  Reflector reflector,
) {
  return ReflectedParameter(
    mirror.simpleName,
    mirror.metadata
        .map(reflector.reflectInstance)
        .whereType<ReflectedInstance>()
        .toList(),
    reflector is GeneratedReflector
        ? reflector._reflectTypeOrDescribe(mirror.type.reflectedType)
        : reflector.reflectType(mirror.type.reflectedType)!,
    !mirror.isOptional,
    mirror.isNamed,
    hasDefaultValue: _hasDefaultValue(mirror),
  );
}

/// Whether [mirror] declares a default value; `false` if the [Reflectable]
/// lacks the `DeclarationsCapability` needed to tell (`contained` has it).
bool _hasDefaultValue(ParameterMirror mirror) {
  try {
    return mirror.hasDefaultValue;
  } on NoSuchCapabilityError {
    return false;
  }
}

/// A type [reflectable] cannot reflect: only the [Type] itself is known.
class _ValueReflectedClass extends ReflectedClass {
  const _ValueReflectedClass(Type type)
    : super('$type', const [], const [], const [], const [], type);

  @override
  bool isAssignableTo(ReflectedType? other) =>
      other?.reflectedType == reflectedType;

  @override
  ReflectedInstance newInstance(
    String constructorName,
    List positionalArguments, [
    Map<String, dynamic> namedArguments = const {},
    List<Type> typeArguments = const [],
  ]) {
    throw UnsupportedError('Cannot create a new instance of $reflectedType.');
  }
}

/// A value [reflectable] cannot reflect: only the value and its runtime type
/// are known.
class _ValueReflectedInstance extends ReflectedInstance {
  _ValueReflectedInstance(Object? value)
    : super(
        _ValueReflectedClass(value.runtimeType),
        _ValueReflectedClass(value.runtimeType),
        value,
      );

  @override
  ReflectedInstance getField(String name) {
    throw UnsupportedError('Cannot reflect on fields of $reflectee.');
  }
}
