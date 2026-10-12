import 'dart:async';

//import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_json_serializer/belatuk_json_serializer.dart' as god;
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';

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
    params['broadcast'] = params.containsKey('broadcast')
        ? params['broadcast']
        : (listenForChanges != true);

    var q = _getQueryInner(initialQuery, params);

    if (params.containsKey('reql') == true && params['reql'] is QueryCallback) {
      q = params['reql'](q) as RqlQuery;
    }

    return q;
  }

  RqlQuery _getQueryInner(RqlQuery query, Map params) {
    if (!params.containsKey('query')) {
      return query;
    } else {
      if (params['query'] is RqlQuery) {
        return params['query'] as RqlQuery;
      } else if (params['query'] is QueryCallback) {
        return params['query'](query) as RqlQuery;
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
    } else if (result is Map && result['generated_keys'] is List) {
      var keys = result['generated_keys'] as List;
      if (keys.length == 1) {
        return await read(keys.first.toString());
      }
      return await Future.wait(keys.map((k) => read(k.toString())));
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

  dynamic _serialize(dynamic data) {
    if (data is Map) {
      return data;
    } else if (data is Iterable) {
      return data.map(_serialize).toList();
    } else {
      return god.serializeObject(data);
    }
  }

  dynamic _squeeze(dynamic data) {
    if (data is Map) {
      return data.keys.fold<Map>({}, (map, k) => map..[k.toString()] = data[k]);
    } else if (data is Iterable) {
      return data.map(_squeeze).toList();
    } else {
      return data;
    }
  }

  StreamSubscription? _feedSubscription;

  @override
  void onHooked(HookedService hookedService) {
    if (listenForChanges == true) {
      // Not awaited, so a failure must be handled here.
      listenToQuery(table, hookedService).catchError(_onFeedError);
    }
  }

  void _onFeedError(Object error, [StackTrace? stackTrace]) {
    if (isAppActive) {
      app.logger.warning('RethinkDB changefeed failed', error, stackTrace);
    }
  }

  /// Cancels the changefeed, if listening.
  @override
  void close() {
    _feedSubscription?.cancel();
    _feedSubscription = null;
    super.close();
  }

  Future listenToQuery(RqlQuery query, HookedService hookedService) async {
    var feed =
        await query.changes({'include_types': true}).run(connection) as Feed;

    void onData(dynamic event) {
      if (event is! Map) return;
      var type = event['type']?.toString();
      var newVal = event['new_val'] is Map ? _toMap(event['new_val']) : null;
      var oldVal = event['old_val'] is Map ? _toMap(event['old_val']) : null;

      HookedServiceEventDispatcher? dispatcher;
      RethinkDbHookedServiceEvent? ev;
      if (type == 'add') {
        dispatcher = hookedService.afterCreated;
        ev = RethinkDbHookedServiceEvent(
          true,
          null,
          null,
          this,
          HookedServiceEvent.created,
          id: newVal?['id']?.toString(),
          result: newVal,
        );
      } else if (type == 'change') {
        dispatcher = hookedService.afterUpdated;
        ev = RethinkDbHookedServiceEvent(
          true,
          null,
          null,
          this,
          HookedServiceEvent.updated,
          id: oldVal?['id']?.toString(),
          data: newVal,
          result: newVal,
        );
      } else if (type == 'remove') {
        dispatcher = hookedService.afterRemoved;
        ev = RethinkDbHookedServiceEvent(
          true,
          null,
          null,
          this,
          HookedServiceEvent.removed,
          id: oldVal?['id']?.toString(),
          result: oldVal,
        );
      }
      if (dispatcher != null && ev != null) {
        // An error in a listener must not escape as an uncaught error.
        Future.sync(() => hookedService.fireEvent(dispatcher!, ev!))
            .then((_) {}, onError: _onFeedError);
      }
    }

    await _feedSubscription?.cancel();
    _feedSubscription = feed.listen(onData, onError: _onFeedError);
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

    var d = _squeeze(_serialize(data)) as Map;
    var result = _checkWrite(await (table as Table).insert(d).run(connection));
    // generated_keys is only there when the data had no id.
    var keys = result is Map ? result['generated_keys'] : null;
    var id = keys is List && keys.isNotEmpty ? keys.first : d['id'];
    return await read(id.toString());
  }

  @override
  Future<Map<String, dynamic>> modify(
    String id,
    Map data, [
    Map? params,
  ]) async {
    // The id in the path is the record to change; the primary key cannot be.
    var d = Map.of(_squeeze(_serialize(data)) as Map)..remove('id');
    // A patch cannot create a record: read throws a 404 if there is none.
    await read(id);
    _checkWrite(await _sendQuery(_selectOne(id).update(d)));
    return await read(id);
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map data, [
    Map? params,
  ]) async {
    // The id in the path is the record to replace, whatever the body says.
    var d = Map.of(_squeeze(_serialize(data)) as Map)..['id'] = id;
    if (table is Table) {
      // Replacing a missing record creates it, as with MapService.
      _checkWrite(await _sendQuery((table as Table).get(id).replace(d)));
    } else {
      await read(id);
      _checkWrite(await _sendQuery(_selectOne(id).replace(d)));
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
    _checkWrite(await _sendQuery(_selectOne(id).delete()));
    return prior;
  }
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
