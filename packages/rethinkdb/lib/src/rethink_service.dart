import 'dart:async';
import 'dart:collection';

//import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart' as uuid;

// Extends a RethinkDB query.
typedef QueryCallback = RqlQuery Function(RqlQuery query);

/// Queries a single RethinkDB table or query.
class RethinkService extends Service<String, Map<String, dynamic>> {
  /// If set to `true`, clients can remove all items by passing a `null` `id` to `remove`.
  ///
  /// `false` by default.
  final bool allowRemoveAll;

  /// If set to `true`, parameters in `req.query` are applied to the database query.
  final bool allowQuery;

  final bool debug;

  /// If set to `true`, then a HookedService mounted over this instance
  /// will fire events when RethinkDB pushes events.
  ///
  /// Good for scaling. ;)
  final bool listenForChanges;

  final Connection connection;

  /// Doesn't actually have to be a table, just a RethinkDB query.
  ///
  /// However, a table is the most common usecase.
  final RqlQuery table;

  RethinkService(
    this.connection,
    this.table, {
    this.allowRemoveAll = false,
    this.allowQuery = true,
    this.debug = false,
    this.listenForChanges = true,
  }) : super();

  RqlQuery buildQuery(RqlQuery initialQuery, Map params) {
    _setBroadcast(params);

    var q = _getQueryInner(initialQuery, params);

    if (params['reql'] is Function) {
      q = _callback(params['reql'], q, 'reql');
    }

    return q;
  }

  /// Calls [callback] with [query]. Any function of one argument is accepted,
  /// e.g. `(q) => q.filter(...)`, whose type is not a [QueryCallback]; one
  /// that is ignored would leave the query unfiltered.
  static RqlQuery _callback(Object? callback, RqlQuery query, String name) {
    var result = (callback as dynamic)(query);
    if (result is RqlQuery) return result;
    throw ArgumentError.value(callback, name, 'must return an RqlQuery');
  }

  RqlQuery _getQueryInner(RqlQuery query, Map params) {
    if (!params.containsKey('query')) {
      return query;
    } else {
      if (params['query'] is RqlQuery) {
        return params['query'] as RqlQuery;
      } else if (params['query'] is Function) {
        return _callback(params['query'], query, 'query');
      } else if (params['query'] is! Map || allowQuery != true) {
        return query;
      } else {
        var q = params['query'] as Map;
        return q.keys.fold<RqlQuery>(query, (out, key) {
          var val = q[key];

          if (val is RequestContext ||
              val is ResponseContext ||
              key == 'provider' ||
              val is Providers) {
            return out;
          } else {
            return out.filter({key.toString(): val});
          }
        });
      }
    }
  }

  Future _sendQuery(RqlQuery query) async {
    var result = await query.run(connection);

    if (result is Cursor) {
      return await result.toList();
    } else {
      return result;
    }
  }

  /// RethinkDB reports a failed write in its result instead of throwing:
  /// a duplicate primary key is a 409, other errors a 400.
  static dynamic _checkWrite(dynamic result) {
    if (result is Map && result['errors'] is int && result['errors'] > 0) {
      var message = result['first_error']?.toString() ?? 'Write failed.';
      throw message.startsWith('Duplicate primary key')
          ? AngelHttpException.conflict(message: message)
          : AngelHttpException.badRequest(message: message);
    }
    return result;
  }

  static Map<String, dynamic> _toMap(Object? record) =>
      Map<String, dynamic>.from(record as Map);

  /// The record with [id], as a query that `update`, `replace` and `delete`
  /// can follow. [table] may be any query, not only a table, so `get` is used
  /// only on a table.
  ///
  /// The `query` parameter does not apply here: it would replace or filter
  /// this selection, so the operation could reach other records.
  RqlQuery _selectOne(String id) =>
      table is Table ? (table as Table).get(id) : table.filter({'id': id});

  /// Reads the record with [id], or null if there is none.
  Future<Map<String, dynamic>?> _find(String id) async {
    var found = await _sendQuery(_selectOne(id));
    if (found is List) found = found.isEmpty ? null : found.first;
    return found == null ? null : _toMap(found);
  }

  /// A copy of [data] with string keys, as RethinkDB needs.
  static Map<String, dynamic> _stringKeys(Map data) => {
    for (var MapEntry(:key, :value) in data.entries) key.toString(): value,
  };

  Cursor? _feed;

  /// Not null while the changefeed listens for changes.
  StreamSubscription? _feedSubscription;
  Future<void>? _feedStarted;
  bool _closed = false;

  /// Sets `broadcast` in [params], unless given, to whether the events of an
  /// `index` or `remove(null)` are broadcast, as by `AngelWebSocket`: not while
  /// the changefeed listens, as it tells each record they removed. [params]
  /// are those of the events of a [HookedService].
  void _setBroadcast(Map params) {
    if (!params.containsKey('broadcast')) {
      params['broadcast'] = _feedSubscription == null;
    }
  }

  Future<String>? _primaryKey;

  /// The primary key of [table], of its `info`, or `id` for another query.
  /// If `info` fails, as for a user not allowed it, `id` is taken, and it is
  /// looked up again next time.
  Future<String> _key() => _primaryKey ??= _loadPrimaryKey();

  Future<String> _loadPrimaryKey() async {
    if (table is! Table) return 'id';
    try {
      var info = await (table as Table).info().run(connection);
      var key = info is Map ? info['primary_key'] : null;
      return key is String ? key : 'id';
    } catch (e, st) {
      _primaryKey = null;
      if (isAppActive) {
        app.logger.warning(
          'RethinkDB table info failed; taking its primary key to be "id"',
          e,
          st,
        );
      }
      return 'id';
    }
  }

  static const _uuid = uuid.Uuid();
  static const _equality = DeepCollectionEquality();

  /// How long a change this service made is waited for from the changefeed.
  static const _ownChangeLifetime = Duration(minutes: 10);

  /// Whether the changes this service makes are tracked, so that the
  /// changefeed's events of them are not broadcast: from when the feed starts,
  /// a little before it listens, until it stops or fails to start.
  bool _tracking = false;

  /// The writes of this service in progress, by the key of their record.
  final Map<String, int> _writing = {};

  /// The changes this service made, by the key of their record, that the
  /// changefeed is yet to tell.
  final Map<String, List<_OwnChange>> _ownChanges = {};

  /// The changes of [_ownChanges], and those already taken off it, oldest
  /// first, so that those the changefeed does not tell are forgotten.
  final Queue<_OwnChange> _ownChangesInOrder = Queue();

  /// The changefeed's events of the records this service is writing, by key,
  /// in order, held until the writes return, to tell whether they are theirs.
  final Map<String, List<_FeedChange>> _held = {};

  /// Runs [write], which changes the record with [key] with `return_changes`,
  /// and checks its result. The service's own events of the change are
  /// broadcast, with their request and params, so the changefeed's event of
  /// the change, the one with the same values, is not.
  Future<dynamic> _ownWrite(
    String key,
    Future<dynamic> Function() write,
  ) async {
    if (!_tracking) return _checkWrite(await write());

    _writing.update(key, (n) => n + 1, ifAbsent: () => 1);
    List changes = const [];
    try {
      var result = _checkWrite(await write());
      if (result is Map && result['changes'] is List) {
        changes = result['changes'] as List;
      }
      return result;
    } finally {
      var writing = (_writing[key] ?? 1) - 1;
      if (writing > 0) {
        _writing[key] = writing;
      } else {
        _writing.remove(key);
      }
      // A write that changed nothing, or failed, has no changes.
      _forgetExpired();
      for (var change in changes) {
        if (change is Map && _tracking) {
          var own = _OwnChange(key, change['old_val'], change['new_val']);
          (_ownChanges[key] ??= []).add(own);
          _ownChangesInOrder.add(own);
        }
      }
      _release(key);
    }
  }

  /// Takes the change this service made to the record with [key] from
  /// [oldVal] to [newVal] off [_ownChanges]; whether there was one. A change
  /// is the same by its old and new values, but for a null one, as a
  /// changefeed over a query tells a record entering or leaving it.
  bool _takeOwnChange(String key, Object? oldVal, Object? newVal) {
    _forgetExpired();
    var changes = _ownChanges[key];
    if (changes == null) return false;
    for (var own in changes) {
      if ((oldVal == null || _equality.equals(own.oldVal, oldVal)) &&
          (newVal == null || _equality.equals(own.newVal, newVal))) {
        _forget(own);
        return true;
      }
    }
    return false;
  }

  void _forget(_OwnChange own) {
    var changes = _ownChanges[own.key];
    if (changes != null && changes.remove(own) && changes.isEmpty) {
      _ownChanges.remove(own.key);
    }
    own.forget();
  }

  /// Forgets the changes the changefeed did not tell in time, and drops those
  /// already taken off [_ownChanges], oldest first.
  void _forgetExpired() {
    var expired = DateTime.now().subtract(_ownChangeLifetime);
    while (_ownChangesInOrder.isNotEmpty) {
      var own = _ownChangesInOrder.first;
      if (!own.forgotten && own.madeAt.isAfter(expired)) break;
      _ownChangesInOrder.removeFirst();
      _forget(own);
    }
  }

  /// Forgets all the changes this service made, of a changefeed that stops.
  void _forgetAll() {
    _ownChanges.clear();
    for (var own in _ownChangesInOrder) {
      own.forget();
    }
    _ownChangesInOrder.clear();
  }

  /// Fires the held events of the record with [key], in order: one of a
  /// change of this service, not broadcast, and others, broadcast, once no
  /// write of the record is in progress, which may have made them.
  void _release(String key) {
    var held = _held[key];
    if (held == null) return;
    while (held.isNotEmpty) {
      var change = held.first;
      if (_takeOwnChange(key, change.oldVal, change.newVal)) {
        held.removeAt(0);
        change.fire(false);
      } else if (_writing.containsKey(key)) {
        break;
      } else {
        held.removeAt(0);
        change.fire(true);
      }
    }
    if (held.isEmpty) _held.remove(key);
  }

  /// Fires the held events of a changefeed that stops, as [_release] does,
  /// without waiting for the writes in progress.
  void _releaseAll() {
    var held = Map.of(_held);
    _held.clear();
    held.forEach((key, changes) {
      for (var change in changes) {
        change.fire(!_takeOwnChange(key, change.oldVal, change.newVal));
      }
    });
  }

  /// Completes when the changefeed listens for changes, or has failed, if
  /// [listenForChanges] is `true` and a [HookedService] is mounted over this
  /// service; completes at once otherwise.
  Future<void> get changefeedStarted => _feedStarted ?? Future.value();

  @override
  void onHooked(HookedService hookedService) {
    if (listenForChanges == true) {
      // Not awaited, so a failure must be handled here.
      _feedStarted = listenToQuery(table, hookedService).then(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (_feedSubscription == null) _stopTracking();
          _onFeedError(error, stackTrace);
        },
      );
    }
  }

  void _onFeedError(Object error, [StackTrace? stackTrace]) {
    if (isAppActive) {
      app.logger.warning('RethinkDB changefeed failed', error, stackTrace);
    }
  }

  /// Stops the changefeed, if listening, also one that is still starting.
  @override
  void close() {
    _closed = true;
    _stopFeed();
    _stopTracking();
    super.close();
  }

  /// Stops tracking the changes this service makes, as the changefeed no
  /// longer tells them, and fires the events it held.
  void _stopTracking() {
    _tracking = false;
    _releaseAll();
    _forgetAll();
  }

  void _stopFeed() {
    _feedSubscription?.cancel();
    _feedSubscription = null;
    // Closing the cursor stops the query on the server.
    _feed?.close();
    _feed = null;
  }

  Future listenToQuery(RqlQuery query, HookedService hookedService) async {
    // Tracked from now, so that a write made while the feed starts is known.
    if (!_closed) _tracking = true;
    // The key of the records, by which the changes this service makes are
    // known: [query] is taken to be over the records of [table].
    var key = await _key();
    // A Feed, or for some queries another Cursor, such as an AtomFeed for a
    // single record.
    var feed =
        await query.changes({'include_types': true}).run(connection) as Cursor;
    if (_closed) {
      // close() came while the feed was starting. Not awaited: the cursor's
      // stream, which nobody listens to, never reports that it is done.
      feed.close();
      return;
    }

    void onData(dynamic event) {
      if (event is! Map) return;
      var type = event['type']?.toString();
      var newVal = event['new_val'] is Map ? _toMap(event['new_val']) : null;
      var oldVal = event['old_val'] is Map ? _toMap(event['old_val']) : null;

      HookedServiceEventDispatcher? dispatcher;
      String eventName;
      Map<String, dynamic>? data, result;
      if (type == 'add') {
        dispatcher = hookedService.afterCreated;
        eventName = HookedServiceEvent.created;
        result = newVal;
      } else if (type == 'change') {
        dispatcher = hookedService.afterUpdated;
        eventName = HookedServiceEvent.updated;
        data = result = newVal;
      } else if (type == 'remove') {
        dispatcher = hookedService.afterRemoved;
        eventName = HookedServiceEvent.removed;
        result = oldVal;
      } else {
        return;
      }
      var id = (oldVal ?? newVal)?[key]?.toString();

      void fire(bool broadcast) {
        var ev = RethinkDbHookedServiceEvent(
          true,
          null,
          null,
          this,
          eventName,
          id: id,
          data: data,
          params: broadcast ? null : {'broadcast': false},
          result: result,
        );
        // An error in a listener must not escape as an uncaught error.
        Future.sync(() => hookedService.fireEvent(dispatcher!, ev))
            .then((_) {}, onError: _onFeedError);
      }

      if (id == null) {
        fire(true);
      } else {
        // Held while the service writes the record, to tell whether the
        // change is its own.
        (_held[id] ??= []).add(_FeedChange(oldVal, newVal, fire));
        _release(id);
      }
    }

    _stopFeed();
    _releaseAll();
    _feed = feed;
    _feedSubscription = feed.listen(
      onData,
      onError: _onFeedError,
      // E.g. the connection closed: the feed no longer listens.
      onDone: () {
        _feedSubscription = null;
        _feed = null;
        _stopTracking();
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> index([Map? params]) async {
    var query = buildQuery(table, params ?? {});
    var result = await _sendQuery(query);
    // A query for a single record (e.g. a `query` parameter using `get`)
    // gives a Map or null.
    if (result == null) return [];
    if (result is Map) return [_toMap(result)];
    return [for (var record in result as List) _toMap(record)];
  }

  @override
  Future<Map<String, dynamic>> read(String id, [Map? params]) async {
    var found = await _find(id);
    if (found == null) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    }
    return found;
  }

  @override
  Future<Map<String, dynamic>> create(Map data, [Map? params]) async {
    if (table is! Table) throw AngelHttpException.methodNotAllowed();

    // The key is given here, not by RethinkDB, to know the record's change.
    var key = await _key();
    var d = _stringKeys(data);
    d[key] ??= _uuid.v4();
    var id = d[key].toString();
    // The record the insert reports, so that a key that is not a string, which
    // read would look up as one, is found.
    return await _written(
      id,
      await _ownWrite(
        id,
        () => _sendQuery((table as Table).insert(d, {'return_changes': true})),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> modify(
    String id,
    Map data, [
    Map? params,
  ]) async {
    // The id in the path is the record to change; the primary key cannot be.
    var d = _stringKeys(data)..remove(await _key());
    // A patch cannot create a record: read throws a 404 if there is none.
    await read(id);
    return await _written(
      id,
      await _ownWrite(
        id,
        () => _sendQuery(_selectOne(id).update(d, {'return_changes': true})),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map data, [
    Map? params,
  ]) async {
    // The id in the path is the record to replace, whatever the body says.
    var d = _stringKeys(data)..[await _key()] = id;
    // Replacing a missing record of a table creates it, as with MapService.
    if (table is! Table) await read(id);
    return await _written(
      id,
      await _ownWrite(
        id,
        () => _sendQuery(_selectOne(id).replace(d, {'return_changes': true})),
      ),
    );
  }

  /// The record with [id] after a write with `return_changes`, whose
  /// [result] has it, so that a record the write moved out of the query is
  /// still returned. Read again when the write changed nothing.
  Future<Map<String, dynamic>> _written(String id, dynamic result) async {
    var changes = result is Map ? result['changes'] : null;
    if (changes is List &&
        changes.isNotEmpty &&
        changes.first is Map &&
        changes.first['new_val'] is Map) {
      return _toMap(changes.first['new_val']);
    }
    return await read(id);
  }

  /// Removes the record with [id]. With a null [id] (or `'null'`), removes
  /// every record matching the query instead and returns RethinkDB's result
  /// (e.g. `{'deleted': 3, ...}`); clients may only do that if
  /// [allowRemoveAll] is `true`.
  @override
  Future<Map<String, dynamic>> remove(String? id, [Map? params]) async {
    if (id == null || id == 'null') {
      if (allowRemoveAll != true && params?.containsKey('provider') == true) {
        throw AngelHttpException.forbidden(
          message: 'Clients are not allowed to delete all items.',
        );
      }
      var result = _checkWrite(
        await _sendQuery(buildQuery(table, params ?? {}).delete()),
      );
      return _toMap(result);
    }

    var prior = await read(id);
    await _ownWrite(
      id,
      () => _sendQuery(_selectOne(id).delete({'return_changes': true})),
    );
    return prior;
  }
}

/// A change this service made to the record with [key], that the changefeed
/// is to tell, forgotten if it does not in time.
class _OwnChange {
  final String key;
  Object? oldVal, newVal;
  final DateTime madeAt = DateTime.now();
  bool forgotten = false;

  _OwnChange(this.key, this.oldVal, this.newVal);

  /// Marks it forgotten, and drops its values, which it may outlive in
  /// [RethinkService._ownChangesInOrder].
  void forget() {
    forgotten = true;
    oldVal = newVal = null;
  }
}

/// A change the changefeed told, of which [fire] fires the event.
class _FeedChange {
  final Object? oldVal, newVal;
  final void Function(bool broadcast) fire;

  _FeedChange(this.oldVal, this.newVal, this.fire);
}

class RethinkDbHookedServiceEvent
    extends HookedServiceEvent<String, Map<String, dynamic>, RethinkService> {
  RethinkDbHookedServiceEvent(
    super.isAfter,
    super.request,
    super.response,
    super.service,
    super.eventName, {
    super.id,
    super.data,
    super.params,
    super.result,
  });
}
