library;

import 'dart:async';

import 'package:angel3_http_exception/angel3_http_exception.dart';
import 'package:belatuk_merge_map/belatuk_merge_map.dart';
import 'package:quiver/core.dart';

import '../util.dart';
import 'anonymous_service.dart';
import 'hooked_service.dart' show HookedService;
import 'metadata.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'server.dart';

/// Indicates how the service was accessed.
///
/// This will be passed to the `params` object in a service method.
/// When requested on the server side, this will be null.
class Providers {
  /// The transport through which the client is accessing this service.
  final String via;

  const Providers(this.via);

  static const String viaRest = 'rest';
  static const String viaWebsocket = 'websocket';
  static const String viaGraphQL = 'graphql';

  /// Represents a request via REST.
  static const Providers rest = Providers(viaRest);

  /// Represents a request over WebSockets.
  static const Providers websocket = Providers(viaWebsocket);

  /// Represents a request parsed from GraphQL.
  static const Providers graphQL = Providers(viaGraphQL);

  @override
  int get hashCode => hashObjects([via]);

  @override
  bool operator ==(other) => other is Providers && other.via == via;

  Map<String, String> toJson() {
    return {'via': via};
  }

  @override
  String toString() {
    return 'via:$via';
  }
}

/// A front-facing interface that can present data to and operate on data on behalf of the user.
///
/// Heavily inspired by FeathersJS. <3
class Service<Id, Data> extends Routable {
  /// A [List] of keys that services should ignore, should they see them in the query.
  static const List<String> specialQueryKeys = <String>[
    r'$limit',
    r'$sort',
    'page',
    'token',
  ];

  /// Handlers that must run to ensure this service's functionality.
  List<RequestHandler> get bootstrappers => [];

  /// The [Angel] app powering this service.
  Angel? _app;

  Angel get app {
    if (_app == null) {
      throw ArgumentError("Angel is not initialized");
    }
    return _app!;
  }

  set app(Angel angel) {
    _app = angel;
  }

  bool get isAppActive => _app != null;

  /// Closes this service, including any database connections or stream controllers.
  @override
  void close() {}

  /// An optional [readData] function can be passed to handle non-map/non-json bodies.
  Service({
    FutureOr<Data> Function(RequestContext, ResponseContext)? readData,
  }) {
    _readData = readData;

    _readData ??= (req, res) {
      if (req.bodyAsObject is! Data) {
        throw AngelHttpException.badRequest(
          message:
              'Invalid request body. Expected $Data; found ${req.bodyAsObject} instead.',
        );
      } else {
        return req.bodyAsObject as Data;
      }
    };
  }

  FutureOr<Data> Function(RequestContext, ResponseContext)? _readData;

  /// A [Function] that reads the request body and converts it into [Data].
  FutureOr<Data> Function(RequestContext, ResponseContext)? get readData =>
      _readData;

  /// Retrieves the first object from the result of calling [index] with the given [params].
  ///
  /// If the result of [index] is `null`, OR an empty [Iterable], a 404 `AngelHttpException` will be thrown.
  ///
  /// If the result is both non-null and NOT an [Iterable], it will be returned as-is.
  ///
  /// If the result is a non-empty [Iterable], [findOne] will return `it.first`, where `it` is the aforementioned [Iterable].
  ///
  /// A custom [errorMessage] may be provided.
  Future<Data> findOne([
    Map<String, dynamic>? params,
    String errorMessage = 'No record was found matching the given query.',
  ]) {
    return index(params).then((result) {
      if (result.isEmpty) {
        throw AngelHttpException.notFound(message: errorMessage);
      } else {
        return result.first;
      }
    });
  }

  /// Retrieves all resources.
  Future<List<Data>> index([Map<String, dynamic>? params]) {
    throw AngelHttpException.methodNotAllowed();
  }

  /// Retrieves the desired resource.
  Future<Data> read(Id id, [Map<String, dynamic>? params]) {
    throw AngelHttpException.methodNotAllowed();
  }

  /// Reads multiple resources at once.
  ///
  /// Service implementations should override this to ensure data is fetched within a
  /// single round trip.
  Future<List<Data>> readMany(List<Id> ids, [Map<String, dynamic>? params]) {
    return Future.wait(ids.map((id) => read(id, params)));
  }

  /// Creates a resource.
  Future<Data> create(Data data, [Map<String, dynamic>? params]) {
    throw AngelHttpException.methodNotAllowed();
  }

  /// Modifies a resource.
  Future<Data> modify(Id id, Data data, [Map<String, dynamic>? params]) {
    throw AngelHttpException.methodNotAllowed();
  }

  /// Overwrites a resource.
  Future<Data> update(Id id, Data data, [Map<String, dynamic>? params]) {
    throw AngelHttpException.methodNotAllowed();
  }

  /// Removes the given resource.
  Future<Data> remove(Id id, [Map<String, dynamic>? params]) {
    throw AngelHttpException.methodNotAllowed();
  }

  /// Creates an [AnonymousService] that wraps over this one, and maps input and output
  /// using two converter functions.
  ///
  /// Handy utility for handling data in a type-safe manner.
  Service<Id, U> map<U>(
    U Function(Data) encoder,
    Data Function(U) decoder, {
    FutureOr<U> Function(RequestContext, ResponseContext)? readData,
  }) {
    readData ??= (req, res) async {
      var inner = await this.readData!(req, res)!;
      return encoder(inner);
    };

    return AnonymousService<Id, U>(
      readData: readData,
      index: ([params]) {
        return index(params).then((it) => it.map(encoder).toList());
      },
      read: (id, [params]) {
        return read(id, params).then(encoder);
      },
      create: (data, [params]) {
        return create(decoder(data), params).then(encoder);
      },
      modify: (id, data, [params]) {
        return modify(id, decoder(data), params).then(encoder);
      },
      update: (id, data, [params]) {
        return update(id, decoder(data), params).then(encoder);
      },
      remove: (id, [params]) {
        return remove(id, params).then(encoder);
      },
    );
  }

  /// Transforms an [id] (whether it is a String, num, etc.) into one acceptable by a service.
  ///
  /// The single type argument, [T], is used to determine how to parse the [id].
  ///
  /// For example, `parseId<bool>` attempts to parse the value as a [bool].
  /// Nullable types (e.g. `int?`) are parsed like their non-nullable form.
  ///
  /// A `null` (or `'null'`) id becomes `'null'`, which only types that accept
  /// a [String] can hold; for others, and for ids that cannot be parsed as
  /// [T], a [FormatException] is thrown (a 400 response over REST).
  static T parseId<T>(Object? id) {
    if (id == null || id == 'null') {
      if ('null' is T) return 'null' as T;
      throw FormatException('Invalid ID "null".');
    } else if (_isType<T, String>()) {
      return id.toString() as T;
    } else if (_isType<T, int>()) {
      return int.parse(id.toString()) as T;
    } else if (_isType<T, bool>()) {
      if (id is bool) return id as T;
      return switch (id.toString()) {
        'true' => true,
        'false' => false,
        _ => throw FormatException('Invalid ID "$id".'),
      } as T;
    } else if (_isType<T, double>()) {
      return double.parse(id.toString()) as T;
    } else if (_isType<T, num>()) {
      return num.parse(id.toString()) as T;
    } else {
      return id as T;
    }
  }

  /// Whether [T] is [S] or `S?`.
  static bool _isType<T, S>() => <S>[] is List<T> && <T>[] is List<S?>;

  /// [parseId] with this service's own [Id] type.
  ///
  /// Routes use this rather than their own type argument: a [HookedService]
  /// created by `app.use` usually has a `dynamic` Id, which would pass the
  /// raw path segment (a [String]) to a service with, say, `int` ids.
  Id _parseId(Object? id) => parseId<Id>(id);

  bool _acceptsId(Object? id) => id is Id;

  /// Generates RESTful routes pointing to this class's methods.
  void addRoutes([Service? service]) {
    _addRoutesInner(service ?? this, bootstrappers);
  }

  void _addRoutesInner(Service service, Iterable<RequestHandler> handlerss) {
    var restProvider = {'provider': Providers.rest};
    var handlers = List<RequestHandler>.from(handlerss);

    // Add global middleware if declared on the instance itself
    var before = getAnnotation<Middleware>(service, app.container.reflector);

    if (before != null) handlers.addAll(before.handlers);

    var indexMiddleware = getAnnotation<Middleware>(
      service.index,
      app.container.reflector,
    );
    get(
      '/',
      (req, res) {
        return index(
          mergeMap([
            {'query': req.queryParameters},
            restProvider,
            req.serviceParams,
          ]),
        );
      },
      middleware: [
        ...handlers,
        ...(indexMiddleware == null) ? [] : indexMiddleware.handlers.toList(),
      ],
    );

    var createMiddleware = getAnnotation<Middleware>(
      service.create,
      app.container.reflector,
    );
    post(
      '/',
      (req, ResponseContext res) {
        return req.parseBody().then((_) async {
          return await create(
            (await readData!(req, res))!,
            mergeMap([
              {'query': req.queryParameters},
              restProvider,
              req.serviceParams,
            ]),
          ).then((r) {
            res.statusCode = 201;
            return r;
          });
        });
      },
      middleware: [
        ...handlers,
        ...(createMiddleware == null) ? [] : createMiddleware.handlers.toList(),
      ],
    );

    var readMiddleware = getAnnotation<Middleware>(
      service.read,
      app.container.reflector,
    );

    get(
      '/:id',
      (req, res) {
        return read(
          service._parseId(req.params['id']),
          mergeMap([
            {'query': req.queryParameters},
            restProvider,
            req.serviceParams,
          ]),
        );
      },
      middleware: [
        ...handlers,
        ...(readMiddleware == null) ? [] : readMiddleware.handlers.toList(),
      ],
    );

    var modifyMiddleware = getAnnotation<Middleware>(
      service.modify,
      app.container.reflector,
    );

    patch(
      '/:id',
      (req, res) {
        return req.parseBody().then((_) async {
          return await modify(
            service._parseId(req.params['id']),
            (await readData!(req, res))!,
            mergeMap([
              {'query': req.queryParameters},
              restProvider,
              req.serviceParams,
            ]),
          );
        });
      },
      middleware: [
        ...handlers,
        ...(modifyMiddleware == null) ? [] : modifyMiddleware.handlers.toList(),
      ],
    );

    var updateMiddleware = getAnnotation<Middleware>(
      service.update,
      app.container.reflector,
    );
    post(
      '/:id',
      (req, res) {
        return req.parseBody().then((_) async {
          return await update(
            service._parseId(req.params['id']),
            (await readData!(req, res))!,
            mergeMap([
              {'query': req.queryParameters},
              restProvider,
              req.serviceParams,
            ]),
          );
        });
      },
      middleware: [
        ...handlers,
        ...(updateMiddleware == null) ? [] : updateMiddleware.handlers.toList(),
      ],
    );

    put(
      '/:id',
      (req, res) {
        return req.parseBody().then((_) async {
          return await update(
            service._parseId(req.params['id']),
            (await readData!(req, res))!,
            mergeMap([
              {'query': req.queryParameters},
              restProvider,
              req.serviceParams,
            ]),
          );
        });
      },
      middleware: [
        ...handlers,
        ...(updateMiddleware == null) ? [] : updateMiddleware.handlers.toList(),
      ],
    );

    var removeMiddleware = getAnnotation<Middleware>(
      service.remove,
      app.container.reflector,
    );
    delete(
      '/',
      (req, res) {
        // "Remove all" is requested with the id 'null' (see [parseId]), which
        // only String ids can carry. Check the wrapped [service]: a
        // HookedService created by `app.use` usually has a `dynamic` Id.
        if (!service._acceptsId('null')) {
          throw AngelHttpException.methodNotAllowed();
        }
        return remove(
          'null' as Id,
          mergeMap([
            {'query': req.queryParameters},
            restProvider,
            req.serviceParams,
          ]),
        );
      },
      middleware: [
        ...handlers,
        ...(removeMiddleware == null) ? [] : removeMiddleware.handlers.toList(),
      ],
    );

    delete(
      '/:id',
      (req, res) {
        return remove(
          service._parseId(req.params['id']),
          mergeMap([
            {'query': req.queryParameters},
            restProvider,
            req.serviceParams,
          ]),
        );
      },
      middleware: [
        ...handlers,
        ...(removeMiddleware == null) ? [] : removeMiddleware.handlers.toList(),
      ],
    );

    // REST compliance
    put('/', (req, res) => throw AngelHttpException.notFound());
    patch('/', (req, res) => throw AngelHttpException.notFound());
  }

  /// Invoked when this service is wrapped within a [HookedService].
  void onHooked(HookedService hookedService) {}
}
