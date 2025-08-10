library;

import 'dart:async';

import '../util.dart';
import 'metadata.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'server.dart';
import 'service.dart';

/// Wraps another service in a service that broadcasts events on actions.
class HookedService<Id, Data, T extends Service<Id, Data>>
    extends Service<Id, Data> {
  final List<StreamController<HookedServiceEvent>> _ctrl = [];

  /// Tbe service that is proxied by this hooked one.
  final T inner;

  final HookedServiceEventDispatcher<Id, Data, T> beforeIndexed =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> beforeRead =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> beforeCreated =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> beforeModified =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> beforeUpdated =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> beforeRemoved =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> afterIndexed =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> afterRead =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> afterCreated =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> afterModified =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> afterUpdated =
      HookedServiceEventDispatcher<Id, Data, T>();
  final HookedServiceEventDispatcher<Id, Data, T> afterRemoved =
      HookedServiceEventDispatcher<Id, Data, T>();

  HookedService(this.inner) {
    // Clone app instance
    if (inner.isAppActive) {
      app = inner.app;
    }
  }

  @override
  FutureOr<Data> Function(RequestContext, ResponseContext)? get readData =>
      inner.readData;

  RequestContext? _getRequest(Map? params) {
    if (params == null) return null;
    return params['__requestctx'] as RequestContext?;
  }

  ResponseContext? _getResponse(Map? params) {
    if (params == null) return null;
    return params['__responsectx'] as ResponseContext?;
  }

  Map<String, dynamic> _stripReq(Map<String, dynamic>? params) {
    if (params == null) {
      return {};
    } else {
      return params.keys
          .where((key) => key != '__requestctx' && key != '__responsectx')
          .fold<Map<String, dynamic>>(
            {},
            (map, key) => map..[key] = params[key],
          );
    }
  }

  /// Closes any open [StreamController]s on this instance. **Internal use only**.
  @override
  Future close() {
    for (var c in _ctrl) {
      c.close();
    }
    beforeIndexed._close();
    beforeRead._close();
    beforeCreated._close();
    beforeModified._close();
    beforeUpdated._close();
    beforeRemoved._close();
    afterIndexed._close();
    afterRead._close();
    afterCreated._close();
    afterModified._close();
    afterUpdated._close();
    afterRemoved._close();
    inner.close();
    return Future.value();
  }

  /// Adds hooks to this instance.
  void addHooks(Angel app) {
    var hooks = getAnnotation<Hooks>(inner, app.container.reflector);
    var before = <HookedServiceEventListener<Id, Data, T>>[];
    var after = <HookedServiceEventListener<Id, Data, T>>[];

    if (hooks != null) {
      before.addAll(hooks.before.cast());
      after.addAll(hooks.after.cast());
    }

    void applyListeners(
      Function fn,
      HookedServiceEventDispatcher<Id, Data, T> dispatcher, [
      bool? isAfter,
    ]) {
      var hooks = getAnnotation<Hooks>(fn, app.container.reflector);
      final listeners = <HookedServiceEventListener<Id, Data, T>>[
        ...isAfter == true ? after : before,
      ];

      if (hooks != null) {
        listeners.addAll((isAfter == true ? hooks.after : hooks.before).cast());
      }

      listeners.forEach(dispatcher.listen);
    }

    applyListeners(inner.index, beforeIndexed);
    applyListeners(inner.read, beforeRead);
    applyListeners(inner.create, beforeCreated);
    applyListeners(inner.modify, beforeModified);
    applyListeners(inner.update, beforeUpdated);
    applyListeners(inner.remove, beforeRemoved);
    applyListeners(inner.index, afterIndexed, true);
    applyListeners(inner.read, afterRead, true);
    applyListeners(inner.create, afterCreated, true);
    applyListeners(inner.modify, afterModified, true);
    applyListeners(inner.update, afterUpdated, true);
    applyListeners(inner.remove, afterRemoved, true);
  }

  @override
  List<RequestHandler> get bootstrappers =>
      List<RequestHandler>.from(super.bootstrappers)
        ..add((RequestContext req, ResponseContext res) {
          req.serviceParams
            ..['__requestctx'] = req
            ..['__responsectx'] = res;
          return true;
        });

  @override
  void addRoutes([Service? service]) {
    super.addRoutes(service ?? inner);
  }

  /// Runs the [listener] before every service method specified.
  void before(
    Iterable<String> eventNames,
    HookedServiceEventListener<Id, Data, T> listener,
  ) {
    eventNames
        .map((name) {
          switch (name) {
            case HookedServiceEvent.indexed:
              return beforeIndexed;
            case HookedServiceEvent.read:
              return beforeRead;
            case HookedServiceEvent.created:
              return beforeCreated;
            case HookedServiceEvent.modified:
              return beforeModified;
            case HookedServiceEvent.updated:
              return beforeUpdated;
            case HookedServiceEvent.removed:
              return beforeRemoved;
            default:
              throw ArgumentError('Invalid service method: $name');
          }
        })
        .forEach(
          (HookedServiceEventDispatcher<Id, Data, T> dispatcher) =>
              dispatcher.listen(listener),
        );
  }

  /// Runs the [listener] after every service method specified.
  void after(
    Iterable<String> eventNames,
    HookedServiceEventListener<Id, Data, T> listener,
  ) {
    eventNames
        .map((name) {
          switch (name) {
            case HookedServiceEvent.indexed:
              return afterIndexed;
            case HookedServiceEvent.read:
              return afterRead;
            case HookedServiceEvent.created:
              return afterCreated;
            case HookedServiceEvent.modified:
              return afterModified;
            case HookedServiceEvent.updated:
              return afterUpdated;
            case HookedServiceEvent.removed:
              return afterRemoved;
            default:
              throw ArgumentError('Invalid service method: $name');
          }
        })
        .forEach(
          (HookedServiceEventDispatcher<Id, Data, T> dispatcher) =>
              dispatcher.listen(listener),
        );
  }

  /// Runs the [listener] before every service method.
  void beforeAll(HookedServiceEventListener<Id, Data, T> listener) {
    beforeIndexed.listen(listener);
    beforeRead.listen(listener);
    beforeCreated.listen(listener);
    beforeModified.listen(listener);
    beforeUpdated.listen(listener);
    beforeRemoved.listen(listener);
  }

  /// Runs the [listener] after every service method.
  void afterAll(HookedServiceEventListener<Id, Data, T> listener) {
    afterIndexed.listen(listener);
    afterRead.listen(listener);
    afterCreated.listen(listener);
    afterModified.listen(listener);
    afterUpdated.listen(listener);
    afterRemoved.listen(listener);
  }

  /// Returns a [Stream] of all events fired before every service method.
  ///
  /// *NOTE*: Only use this if you do not plan to modify events. There is no guarantee
  /// that events coming out of this [Stream] will see changes you make within the [Stream]
  /// callback.
  Stream<HookedServiceEvent<Id, Data, T>> beforeAllStream() {
    var ctrl = StreamController<HookedServiceEvent<Id, Data, T>>();
    _ctrl.add(ctrl);
    before(HookedServiceEvent.all, ctrl.add);
    return ctrl.stream;
  }

  /// Returns a [Stream] of all events fired after every service method.
  ///
  /// *NOTE*: Only use this if you do not plan to modify events. There is no guarantee
  /// that events coming out of this [Stream] will see changes you make within the [Stream]
  /// callback.
  Stream<HookedServiceEvent<Id, Data, T>> afterAllStream() {
    var ctrl = StreamController<HookedServiceEvent<Id, Data, T>>();
    _ctrl.add(ctrl);
    before(HookedServiceEvent.all, ctrl.add);
    return ctrl.stream;
  }

  /// Returns a [Stream] of all events fired before every service method specified.
  ///
  /// *NOTE*: Only use this if you do not plan to modify events. There is no guarantee
  /// that events coming out of this [Stream] will see changes you make within the [Stream]
  /// callback.
  Stream<HookedServiceEvent<Id, Data, T>> beforeStream(
    Iterable<String> eventNames,
  ) {
    var ctrl = StreamController<HookedServiceEvent<Id, Data, T>>();
    _ctrl.add(ctrl);
    before(eventNames, ctrl.add);
    return ctrl.stream;
  }

  /// Returns a [Stream] of all events fired AFTER every service method specified.
  ///
  /// *NOTE*: Only use this if you do not plan to modify events. There is no guarantee
  /// that events coming out of this [Stream] will see changes you make within the [Stream]
  /// callback.
  Stream<HookedServiceEvent<Id, Data, T>> afterStream(
    Iterable<String> eventNames,
  ) {
    var ctrl = StreamController<HookedServiceEvent<Id, Data, T>>();
    _ctrl.add(ctrl);
    after(eventNames, ctrl.add);
    return ctrl.stream;
  }

  /// Runs the [listener] before [create], [modify] and [update].
  void beforeModify(HookedServiceEventListener<Id, Data, T> listener) {
    beforeCreated.listen(listener);
    beforeModified.listen(listener);
    beforeUpdated.listen(listener);
  }

  @override
  Future<List<Data>> index([Map<String, dynamic>? params]) {
    var localParams = _stripReq(params);
    return beforeIndexed
        ._emit(
          HookedServiceEvent(
            false,
            _getRequest(params),
            _getResponse(params),
            inner,
            HookedServiceEvent.indexed,
            params: localParams,
          ),
        )
        .then((before) {
          if (before._canceled) {
            return afterIndexed
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.indexed,
                    params: localParams,
                    result: before.result,
                  ),
                )
                .then((after) => after.result as List<Data>);
          }

          return inner.index(localParams).then((result) {
            return afterIndexed
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.indexed,
                    params: localParams,
                    result: result,
                  ),
                )
                .then((after) => after.result as List<Data>);
          });
        });
  }

  @override
  Future<Data> read(Id id, [Map<String, dynamic>? params]) {
    var localParams = _stripReq(params);
    return beforeRead
        ._emit(
          HookedServiceEvent(
            false,
            _getRequest(params),
            _getResponse(params),
            inner,
            HookedServiceEvent.read,
            id: id,
            params: localParams,
          ),
        )
        .then((before) {
          if (before._canceled) {
            return afterRead
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.read,
                    id: id,
                    params: localParams,
                    result: before.result,
                  ),
                )
                .then((after) => after.result as Data);
          }

          return inner.read(id, localParams).then((result) {
            return afterRead
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.read,
                    id: id,
                    params: localParams,
                    result: result,
                  ),
                )
                .then((after) => after.result as Data);
          });
        });
  }

  @override
  Future<Data> create(Data data, [Map<String, dynamic>? params]) {
    var localParams = _stripReq(params);
    return beforeCreated
        ._emit(
          HookedServiceEvent(
            false,
            _getRequest(params),
            _getResponse(params),
            inner,
            HookedServiceEvent.created,
            data: data,
            params: localParams,
          ),
        )
        .then((before) {
          if (before._canceled) {
            return afterCreated
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.created,
                    data: before.data,
                    params: localParams,
                    result: before.result,
                  ),
                )
                .then((after) => after.result as Data);
          }

          return inner.create(before.data as Data, localParams).then((result) {
            return afterCreated
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.created,
                    data: before.data,
                    params: localParams,
                    result: result,
                  ),
                )
                .then((after) => after.result as Data);
          });
        });
  }

  @override
  Future<Data> modify(Id id, Data data, [Map<String, dynamic>? params]) {
    var localParams = _stripReq(params);
    return beforeModified
        ._emit(
          HookedServiceEvent(
            false,
            _getRequest(params),
            _getResponse(params),
            inner,
            HookedServiceEvent.modified,
            id: id,
            data: data,
            params: localParams,
          ),
        )
        .then((before) {
          if (before._canceled) {
            return afterModified
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.modified,
                    id: id,
                    data: before.data,
                    params: localParams,
                    result: before.result,
                  ),
                )
                .then((after) => after.result as Data);
          }

          return inner.modify(id, before.data as Data, localParams).then((
            result,
          ) {
            return afterModified
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.created,
                    id: id,
                    data: before.data,
                    params: localParams,
                    result: result,
                  ),
                )
                .then((after) => after.result as Data);
          });
        });
  }

  @override
  Future<Data> update(Id id, Data data, [Map<String, dynamic>? params]) {
    var localParams = _stripReq(params);
    return beforeUpdated
        ._emit(
          HookedServiceEvent(
            false,
            _getRequest(params),
            _getResponse(params),
            inner,
            HookedServiceEvent.updated,
            id: id,
            data: data,
            params: localParams,
          ),
        )
        .then((before) {
          if (before._canceled) {
            return afterUpdated
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.updated,
                    id: id,
                    data: before.data,
                    params: localParams,
                    result: before.result,
                  ),
                )
                .then((after) => after.result as Data);
          }

          return inner.update(id, before.data as Data, localParams).then((
            result,
          ) {
            return afterUpdated
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.updated,
                    id: id,
                    data: before.data,
                    params: localParams,
                    result: result,
                  ),
                )
                .then((after) => after.result as Data);
          });
        });
  }

  @override
  Future<Data> remove(Id id, [Map<String, dynamic>? params]) {
    var localParams = _stripReq(params);
    return beforeRemoved
        ._emit(
          HookedServiceEvent(
            false,
            _getRequest(params),
            _getResponse(params),
            inner,
            HookedServiceEvent.removed,
            id: id,
            params: localParams,
          ),
        )
        .then((before) {
          if (before._canceled) {
            return afterRemoved
                    ._emit(
                      HookedServiceEvent(
                        true,
                        _getRequest(params),
                        _getResponse(params),
                        inner,
                        HookedServiceEvent.removed,
                        id: id,
                        params: localParams,
                        result: before.result,
                      ),
                    )
                    .then((after) => after.result)
                as Data;
          }

          return inner.remove(id, localParams).then((result) {
            return afterRemoved
                ._emit(
                  HookedServiceEvent(
                    true,
                    _getRequest(params),
                    _getResponse(params),
                    inner,
                    HookedServiceEvent.removed,
                    id: id,
                    params: localParams,
                    result: result,
                  ),
                )
                .then((after) => after.result as Data);
          });
        });
  }

  /// Fires an `after` event. This will not be propagated to clients,
  /// but will be broadcasted to WebSockets, etc.
  Future<HookedServiceEvent<Id, Data, T>> fire(
    String eventName,
    result, [
    HookedServiceEventListener<Id, Data, T>? callback,
  ]) {
    HookedServiceEventDispatcher<Id, Data, T> dispatcher;

    switch (eventName) {
      case HookedServiceEvent.indexed:
        dispatcher = afterIndexed;
        break;
      case HookedServiceEvent.read:
        dispatcher = afterRead;
        break;
      case HookedServiceEvent.created:
        dispatcher = afterCreated;
        break;
      case HookedServiceEvent.modified:
        dispatcher = afterModified;
        break;
      case HookedServiceEvent.updated:
        dispatcher = afterUpdated;
        break;
      case HookedServiceEvent.removed:
        dispatcher = afterRemoved;
        break;
      default:
        throw ArgumentError("Invalid service event name: '$eventName'");
    }

    var ev = HookedServiceEvent<Id, Data, T>(
      true,
      null,
      null,
      inner,
      eventName,
    );
    return fireEvent(dispatcher, ev, callback);
  }

  /// Sends an arbitrary event down the hook chain.
  Future<HookedServiceEvent<Id, Data, T>> fireEvent(
    HookedServiceEventDispatcher<Id, Data, T> dispatcher,
    HookedServiceEvent<Id, Data, T> event, [
    HookedServiceEventListener<Id, Data, T>? callback,
  ]) {
    Future? f;
    if (callback != null && event._canceled != true) {
      f = Future.sync(() => callback(event));
    }
    f ??= Future.value();
    return f.then((_) => dispatcher._emit(event));
  }
}

/// Fired when a hooked service is invoked.
class HookedServiceEvent<Id, Data, T extends Service<Id, Data>> {
  static const String indexed = 'indexed';
  static const String read = 'read';
  static const String created = 'created';
  static const String modified = 'modified';
  static const String updated = 'updated';
  static const String removed = 'removed';

  static const List<String> all = [
    indexed,
    read,
    created,
    modified,
    updated,
    removed,
  ];

  /// Use this to end processing of an event.
  void cancel([Object? result]) {
    _canceled = true;
    this.result = result ?? this.result;
  }

  /// Resolves a service from the application.
  ///
  /// Shorthand for `e.service.app.service(...)`.
  Service? getService(Pattern path) => service.app.findService(path);

  bool _canceled = false;
  final String _eventName;
  Id? _id;
  final bool _isAfter;
  Data? data;
  Map<String, dynamic>? _params;
  final RequestContext? _request;
  final ResponseContext? _response;
  dynamic result;

  String get eventName => _eventName;

  Id? get id => _id;

  bool get isAfter => _isAfter == true;

  bool get isBefore => !isAfter;

  Map get params => _params ?? {};

  RequestContext? get request => _request;

  ResponseContext? get response => _response;

  /// The inner service whose method was hooked.
  T service;

  HookedServiceEvent(
    this._isAfter,
    this._request,
    this._response,
    this.service,
    this._eventName, {
    Id? id,
    this.data,
    Map<String, dynamic>? params,
    this.result,
  }) {
    //_data = data;
    _id = id;
    _params = params ?? {};
  }
}

/// Triggered on a hooked service event.
typedef HookedServiceEventListener<Id, Data, T extends Service<Id, Data>> =
    FutureOr<dynamic> Function(HookedServiceEvent<Id, Data, T> event);

/// Can be listened to, but events may be canceled.
class HookedServiceEventDispatcher<Id, Data, T extends Service<Id, Data>> {
  final List<StreamController<HookedServiceEvent<Id, Data, T>>> _ctrl = [];
  final List<HookedServiceEventListener<Id, Data, T>> listeners = [];

  void _close() {
    for (var c in _ctrl) {
      c.close();
    }
    listeners.clear();
  }

  /// Fires an event, and returns it once it is either canceled, or all listeners have run.
  Future<HookedServiceEvent<Id, Data, T>> _emit(
    HookedServiceEvent<Id, Data, T> event,
  ) {
    if (event._canceled == true || listeners.isEmpty) {
      return Future.value(event);
    }

    var f = Future<HookedServiceEvent<Id, Data, T>>.value(event);

    for (var listener in listeners) {
      f = f.then((event) {
        if (event._canceled) return event;
        return Future.sync(() => listener(event)).then((_) => event);
      });
    }

    return f;
  }

  /// Returns a [Stream] containing all events fired by this dispatcher.
  ///
  /// *NOTE*: Callbacks on the returned [Stream] cannot be guaranteed to run before other [listeners].
  /// Use this only if you need a read-only stream of events.
  Stream<HookedServiceEvent<Id, Data, T>> asStream() {
    var ctrl = StreamController<HookedServiceEvent<Id, Data, T>>();
    _ctrl.add(ctrl);
    listen(ctrl.add);
    return ctrl.stream;
  }

  /// Registers the listener to be called whenever an event is triggered.
  void listen(HookedServiceEventListener<Id, Data, T> listener) {
    listeners.add(listener);
  }
}
