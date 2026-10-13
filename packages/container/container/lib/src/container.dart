import 'dart:async';

import 'exception.dart';
import 'reflector.dart';

class Container {
  final Reflector reflector;
  final Map<Type, dynamic> _singletons = {};
  final Map<Type, dynamic Function(Container)> _factories = {};
  // Types registered here with registerLazySingleton.
  final Set<Type> _lazyTypes = {};
  final Map<String, dynamic> _namedSingletons = {};
  final Container? _parent;

  Container(this.reflector) : _parent = null;

  Container._child(Container this._parent) : reflector = _parent.reflector;

  bool get isRoot => _parent == null;

  /// Creates a child [Container] that can define its own singletons and factories.
  ///
  /// Use this to create children of a global "scope."
  Container createChild() {
    return Container._child(this);
  }

  /// Determines if the container has an injection of the given type.
  bool has<T>([Type? t]) {
    var t2 = T;
    if (t != null) {
      t2 = t;
    } else if (T == dynamic && t == null) {
      return false;
    }

    Container? search = this;
    while (search != null) {
      if (search._singletons.containsKey(t2)) {
        return true;
      } else if (search._factories.containsKey(t2)) {
        return true;
      } else {
        search = search._parent;
      }
    }

    return false;
  }

  /// Determines if the container has a named singleton with the given [name].
  bool hasNamed(String name) {
    Container? search = this;

    while (search != null) {
      if (search._namedSingletons.containsKey(name)) {
        return true;
      } else {
        search = search._parent;
      }
    }

    return false;
  }

  /// Instantiates an instance of [T], asynchronously.
  ///
  /// It is similar to [make], but resolves an injection of either
  /// `Future<T>` or `T`.
  Future<T> makeAsync<T>([Type? type]) {
    var t2 = T;
    if (type != null) {
      t2 = type;
    }

    Type? futureType; //.Future<T>.value(null).runtimeType;

    if (T == dynamic) {
      try {
        futureType = reflector.reflectFutureOf(t2).reflectedType;
      } on UnsupportedError {
        // Ignore this.
      }
    }

    if (has<T>(t2)) {
      return Future<T>.value(make(t2));
    } else if (has<Future<T>>()) {
      return make<Future<T>>();
    } else if (futureType != null) {
      return make(futureType);
    } else {
      throw ReflectionException(
        'No injection for Future<$t2> or $t2 was found.',
      );
    }
  }

  /// Instantiates an instance of [T].
  ///
  /// In contexts where a static generic type cannot be used, use
  /// the [type] argument, instead of [T].
  T make<T>([Type? type]) => _make(type ?? T, {}) as T;

  /// [resolving] holds the types whose constructors are being resolved in
  /// this call, to detect circular dependencies.
  dynamic _make(Type t2, Set<Type> resolving) {
    Container? search = this;

    while (search != null) {
      // A lazy singleton made by another container belongs to that one: a
      // child calls the factory again, to get its own.
      if (search._singletons.containsKey(t2) &&
          (identical(search, this) || !search._lazyTypes.contains(t2))) {
        // Find a singleton, if any.
        return search._singletons[t2];
      } else if (search._factories.containsKey(t2)) {
        // Find a factory, if any.
        return search._factories[t2]!(this);
      } else {
        search = search._parent;
      }
    }

    if (!resolving.add(t2)) {
      throw ReflectionException(
        'Circular dependency: $t2 depends on itself, and therefore cannot be instantiated.',
      );
    }
    try {
      return _construct(t2, resolving);
    } finally {
      resolving.remove(t2);
    }
  }

  dynamic _construct(Type t2, Set<Type> resolving) {
    var reflectedType = reflector.reflectType(t2);
    var positional = [];
    var named = <String, dynamic>{};

    if (reflectedType is ReflectedClass) {
      bool isDefault(String name) {
        return name.isEmpty || name == reflectedType.name;
      }

      var constructor = reflectedType.constructors.firstWhere(
        (c) => isDefault(c.name),
        orElse: (() => throw ReflectionException(
          '${reflectedType.name} has no default constructor, and therefore cannot be instantiated.',
        )),
      );

      // Once an optional positional parameter is left out, the ones after it
      // cannot be passed either.
      var positionalOmitted = false;
      for (var param in constructor.parameters) {
        var type = param.type.reflectedType;
        // A parameter with a default (an optional positional one defaults to
        // null) keeps it unless something is registered for its type.
        var canOmit =
            param.hasDefaultValue || (!param.isNamed && !param.isRequired);
        if (!param.isNamed && positionalOmitted) continue;
        var registered = has(type);
        if (canOmit && !registered) {
          if (!param.isNamed) positionalOmitted = true;
          continue;
        }

        if (param.isNamed && !param.isRequired && !registered) {
          // Reflectors may not tell `{Logger? log}` from `{required Dep dep}`:
          // construct the value if possible, and leave it out otherwise.
          // Only failures to construct the type are caught; errors thrown
          // while running constructors or factories are not.
          try {
            named[param.name] = _make(type, resolving);
          } catch (e) {
            if (!isUnconstructible(e)) rethrow;
            // Left out; a required parameter then fails in newInstance.
          }
          continue;
        }

        var value = _make(type, resolving);
        if (param.isNamed) {
          named[param.name] = value;
        } else {
          positional.add(value);
        }
      }

      return reflectedType
          .newInstance(
            isDefault(constructor.name) ? '' : constructor.name,
            positional,
            named,
            [],
          )
          .reflectee;
    } else {
      throw ReflectionException(
        '$t2 is not a class, and therefore cannot be instantiated.',
      );
    }
  }

  /// Whether [error] says that a type cannot be constructed by reflection,
  /// as opposed to being thrown by a constructor or factory: a
  /// [ReflectionException], a reflector that cannot reflect the type
  /// ([UnsupportedError], [ArgumentError]), or an abstract class.
  ///
  /// Use it to leave an optional dependency out when [make] cannot build it.
  static bool isUnconstructible(Object error) =>
      error is ReflectionException ||
      error is UnsupportedError ||
      error is ArgumentError ||
      (error is Error &&
          '$error'.startsWith('Cannot instantiate abstract class'));

  /// Shorthand for registering a factory that injects a singleton when it runs.
  ///
  /// The singleton belongs to the container that resolves it: [f] runs with
  /// that container, and its result is registered there. A child container
  /// (e.g. one per request) therefore gets its own instance, which lets [f]
  /// depend on what that child provides, such as the current request, even
  /// if this container has made one for itself. Children of that child share
  /// the child's instance.
  /// Register a plain [registerSingleton] for one instance shared everywhere.
  ///
  /// In many cases, you might prefer this to [registerFactory].
  ///
  /// Returns [f].
  T Function(Container) registerLazySingleton<T>(
    T Function(Container) f, {
    Type? as,
  }) {
    registerFactory<T>((container) {
      var r = f(container);
      container.registerSingleton<T>(r, as: as);
      return r;
    }, as: as);
    _lazyTypes.add(as ?? T);
    return f;
  }

  /// Registers a factory. Any attempt to resolve the
  /// type within *this* container will return the result of [f].
  ///
  /// Returns [f].
  T Function(Container) registerFactory<T>(
    T Function(Container) f, {
    Type? as,
  }) {
    Type t2 = T;
    if (as != null) {
      t2 = as;
    }

    if (_factories.containsKey(t2)) {
      throw StateError('This container already has a factory for $t2.');
    }

    _factories[t2] = f;
    return f;
  }

  /// Registers a singleton. Any attempt to resolve the
  /// type within *this* container will return [object].
  ///
  /// Returns [object].
  T registerSingleton<T>(T object, {Type? as}) {
    Type t2 = T;
    if (as != null) {
      t2 = as;
    } else if (T == dynamic) {
      t2 = as ?? object.runtimeType;
    }
    //as ??= T == dynamic ? as : T;

    if (_singletons.containsKey(t2)) {
      throw StateError('This container already has a singleton for $t2.');
    }

    _singletons[t2] = object;
    return object;
  }

  /// Finds a named singleton.
  ///
  /// In general, prefer using [registerSingleton] and [registerFactory].
  ///
  /// [findByName] is best reserved for internal logic that end users of code should
  /// not see.
  T findByName<T>(String name) {
    if (_namedSingletons.containsKey(name)) {
      return _namedSingletons[name] as T;
    } else if (_parent != null) {
      return _parent.findByName<T>(name);
    } else {
      throw StateError(
        'This container does not have a singleton named "$name".',
      );
    }
  }

  /// Registers a *named* singleton.
  ///
  /// Note that this is not related to type-based injections, and exists as a mechanism
  /// to enable injecting multiple instances of a type within the same container hierarchy.
  T registerNamedSingleton<T>(String name, T object) {
    if (_namedSingletons.containsKey(name)) {
      throw StateError('This container already has a singleton named "$name".');
    }

    _namedSingletons[name] = object;
    return object;
  }
}
