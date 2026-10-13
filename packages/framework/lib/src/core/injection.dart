part of 'request_context.dart';

const List<Type> _primitiveTypes = [String, int, num, double, Null];

/// Shortcut for calling [preInject], and then [handleContained].
///
/// Use this to instantly create a request handler for a DI-enabled method.
///
/// Calling [ioc] also auto-serializes the result of a [handler].
///
/// Pass [injection] to describe the [handler]'s parameters explicitly instead
/// of reflecting on it. This works without reflection (e.g. in AOT-compiled
/// apps), as long as every required type is registered in the container:
///
/// ```dart
/// app.get('/todo', ioc(
///   (Todo todo) => todo,
///   injection: InjectionRequest.constant(required: [Todo]),
/// ));
/// ```
RequestHandler ioc(
  Function handler, {
  Iterable<String> optional = const [],
  InjectionRequest? injection,
}) {
  if (injection != null) {
    var explicit = injection;
    if (optional.isNotEmpty) {
      // Copy, since a const InjectionRequest has unmodifiable lists.
      explicit = InjectionRequest.constant(
        named: injection.named,
        namedWithDefaults: injection.namedWithDefaults,
        required: injection.required,
        optional: [...injection.optional, ...optional],
        parameters: injection.parameters,
      );
    }
    var contained = handleContained(handler, explicit);
    return (req, res) => req.app!.executeHandler(contained, req, res);
  }

  return (req, res) {
    RequestHandler? contained;

    if (req.app?.container != null) {
      var injection = preInject(handler, req.app!.container.reflector);
      //if (injection != null) {
      injection.optional.addAll(optional);
      contained = handleContained(handler, injection);
      //}
    }

    return req.app!.executeHandler(contained, req, res);
  };
}

Future resolveInjection(
  Object requirement,
  InjectionRequest injection,
  RequestContext req,
  ResponseContext res,
  bool throwOnUnresolved, [
  Container? container,
]) async {
  dynamic propFromApp;
  container ??= req.container ?? res.app!.container;

  if (requirement == RequestContext) {
    return req;
  } else if (requirement == ResponseContext) {
    return res;
  } else if (requirement is String &&
      injection.parameters.containsKey(requirement)) {
    var param = injection.parameters[requirement]!;
    var value = param.getValue(req);
    if (value == null && param.required != false) throw param.error as Object;
    return value;
  } else if (requirement is String) {
    if (req.container!.hasNamed(requirement)) {
      return req.container!.findByName(requirement);
    }
    if (req.params.containsKey(requirement)) {
      return req.params[requirement];
    } else if ((propFromApp = req.app!.findProperty(requirement)) != null) {
      return propFromApp;
    } else if (injection.optional.contains(requirement)) {
      return null;
    } else if (throwOnUnresolved) {
      throw ArgumentError(
        "Cannot resolve parameter '$requirement' within handler.",
      );
    }
  } else if (requirement is List &&
      requirement.length == 2 &&
      requirement.first is String &&
      requirement.last is Type) {
    var key = requirement.first;
    var type = requirement.last;
    if (injection.parameters.containsKey(key) ||
        req.params.containsKey(key) ||
        req.app!.configuration.containsKey(key) ||
        _primitiveTypes.contains(type)) {
      return await resolveInjection(
        key,
        injection,
        req,
        res,
        throwOnUnresolved,
        container,
      );
    } else if ((!throwOnUnresolved || injection.optional.contains(key)) &&
        !container.has(type)) {
      // An optional (or named) parameter of a type nothing is registered
      // for: construct one if possible, but leave it unresolved otherwise
      // (e.g. an abstract class) instead of failing the request.
      try {
        return await resolveInjection(
          type,
          injection,
          req,
          res,
          throwOnUnresolved,
          container,
        );
      } catch (e) {
        // Only "cannot be constructed", whichever reflector reports it; an
        // error thrown while constructing it is a real failure, and must
        // reach the client as one.
        if (Container.isUnconstructible(e)) return null;
        rethrow;
      }
    } else {
      return await resolveInjection(
        type,
        injection,
        req,
        res,
        throwOnUnresolved,
        container,
      );
    }
  } else if (requirement is Type && requirement != dynamic) {
    try {
      var futureType = container.reflector.reflectFutureOf(requirement);
      if (container.has(futureType.reflectedType)) {
        return await container.make(futureType.reflectedType);
      }
    } on UnsupportedError {
      // Ignore.
    }

    return await container.make(requirement);
  } else if (throwOnUnresolved) {
    throw ArgumentError(
      '$requirement cannot be injected into a request handler.',
    );
  }
}

/// Checks if an [InjectionRequest] can be sufficiently executed within the current request/response context.
bool suitableForInjection(
  RequestContext req,
  ResponseContext res,
  InjectionRequest injection,
) {
  return injection.parameters.values.any((p) {
    if (p.match == null) return false;
    var value = p.getValue(req);
    return value == p.match;
  });
}

/// Handles a request with a DI-enabled handler.
RequestHandler handleContained(
  Function handler,
  InjectionRequest injection, [
  Container? container,
]) {
  return (RequestContext req, ResponseContext res) async {
    if (injection.parameters.isNotEmpty &&
        injection.parameters.values.any((p) => p.match != null) &&
        !suitableForInjection(req, res, injection)) {
      return Future.value(true);
    }

    var args = [];

    var named = <Symbol, dynamic>{};

    for (var r in injection.required) {
      args.add(await resolveInjection(r, injection, req, res, true, container));
    }

    for (var entry in injection.named.entries) {
      var value = await resolveInjection(
        [entry.key, entry.value],
        injection,
        req,
        res,
        false,
        container,
      );
      // Leave unresolved parameters with a default out, so it applies; others
      // (e.g. `required String? q`) are passed null.
      if (value != null || !injection.namedWithDefaults.contains(entry.key)) {
        named[Symbol(entry.key)] = value;
      }
    }

    return Function.apply(handler, args, named);
  };
}

/// Contains a list of the data required for a DI-enabled method to run.
///
/// This improves performance by removing the necessity to reflect a method
/// every time it is requested.
///
/// Regular request handlers can also skip DI entirely, lowering response time
/// and memory use.
class InjectionRequest {
  /// Optional, typed data that can be passed to a DI-enabled method.
  final Map<String, Type> named;

  /// The names in [named] of parameters with a default value, which are left
  /// out (so the default applies) when they cannot be resolved, instead of
  /// being passed `null`.
  ///
  /// [preInject] fills this from the reflector (`MirrorsReflector` reports
  /// default values; some reflectors cannot). When writing an
  /// [InjectionRequest] by hand, list such parameters here, e.g.
  /// `named: {'page': int}, namedWithDefaults: {'page'}` for
  /// `({int page = 1})`.
  final Set<String> namedWithDefaults;

  /// A list of the arguments required for a DI-enabled method to run.
  final List required;

  /// A list of the arguments that can be null in a DI-enabled method.
  final List<String> optional;

  /// Extended parameter definitions.
  final Map<String, Parameter> parameters;

  const InjectionRequest.constant({
    this.named = const {},
    this.namedWithDefaults = const {},
    this.required = const [],
    this.optional = const [],
    this.parameters = const {},
  });

  InjectionRequest()
    : named = {},
      namedWithDefaults = {},
      required = [],
      optional = [],
      parameters = {};
}

/// Predetermines what needs to be injected for a handler to run.
InjectionRequest preInject(Function handler, Reflector reflector) {
  var closureMirror = reflector.reflectFunction(handler)!;
  if (closureMirror.parameters.isEmpty) return InjectionRequest();

  // Only reflected when a parameter has annotations: a reflector without
  // information about [Parameter] (e.g. a StaticReflector) throws.
  ReflectedType? parameterType;

  return injectionFromParameters(
    closureMirror.parameters.map(
      (parameter) => InjectableParameter(
        name: parameter.name,
        type: parameter.type.reflectedType,
        isRequired: parameter.isRequired,
        isNamed: parameter.isNamed,
        hasDefaultValue: parameter.hasDefaultValue,
        annotation:
            parameter.annotations
                    .firstWhereOrNull(
                      (m) => m.type.isAssignableTo(
                        parameterType ??= reflector.reflectType(Parameter),
                      ),
                    )
                    ?.reflectee
                as Parameter?,
      ),
    ),
  );
}

/// A reflector-independent description of one parameter of a DI-enabled
/// handler, from which [injectionFromParameters] builds an [InjectionRequest].
///
/// This lets code that discovers handlers by other means (e.g. `dart:mirrors`
/// directly, or generated code) inject them without the app's [Reflector].
class InjectableParameter {
  final String name;
  final Type type;

  /// Whether a positional parameter is required (not in `[...]`).
  final bool isRequired;
  final bool isNamed;
  final bool hasDefaultValue;

  /// The parameter's [Parameter] annotation, if any.
  final Parameter? annotation;

  const InjectableParameter({
    required this.name,
    required this.type,
    required this.isRequired,
    required this.isNamed,
    this.hasDefaultValue = false,
    this.annotation,
  });
}

/// Builds the [InjectionRequest] for a handler with the given [parameters].
///
/// [preInject] uses this after reflecting on a handler.
InjectionRequest injectionFromParameters(
  Iterable<InjectableParameter> parameters,
) {
  var injection = InjectionRequest();

  for (var parameter in parameters) {
    var name = parameter.name;
    var type = parameter.type;
    var p = parameter.annotation;

    if (p != null) {
      injection.parameters[name] = Parameter(
        cookie: p.cookie,
        header: p.header,
        query: p.query,
        session: p.session,
        match: p.match,
        defaultValue: p.defaultValue,
        required: parameter.isNamed ? false : p.required != false,
      );
    }

    if (!parameter.isNamed) {
      if (!parameter.isRequired) injection.optional.add(name);

      if (type == RequestContext || type == ResponseContext) {
        injection.required.add(type);
      } else if (name == 'req') {
        injection.required.add(RequestContext);
      } else if (name == 'res') {
        injection.required.add(ResponseContext);
      } else if (type == dynamic) {
        injection.required.add(name);
      } else {
        injection.required.add([name, type]);
      }
    } else {
      injection.named[name] = type;
      if (parameter.hasDefaultValue) injection.namedWithDefaults.add(name);
    }
  }
  return injection;
}
