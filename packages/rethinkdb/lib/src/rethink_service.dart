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
        return params['query'](table) as RqlQuery;
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
      if (result['generated_keys'].length == 1) {
        return await read(result['generated_keys'].first);
      }
      //return await Future.wait(result['generated_keys'].map(read));
      return await result['generated_keys'].map(read);
    } else {
      return result;
    }
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

  @override
  void onHooked(HookedService hookedService) {
    if (listenForChanges == true) {
      listenToQuery(table, hookedService);
    }
  }

  Future listenToQuery(RqlQuery query, HookedService hookedService) async {
    var feed =
        await query.changes({'include_types': true}).run(connection) as Feed;

    Future<dynamic> onData(dynamic event) {
      if (event != null && event is Map) {
        var type = event['type']?.toString();
        var newVal = event['new_val'];
        var oldVal = event['old_val'];

        if (type == 'add') {
          // Create

          hookedService.fireEvent(
            hookedService.afterCreated,
            RethinkDbHookedServiceEvent(
              true,
              null,
              null,
              this,
              HookedServiceEvent.created,
              result: newVal,
            ),
          );
        } else if (type == 'change') {
          // Update
          hookedService.fireEvent(
            hookedService.afterCreated,
            RethinkDbHookedServiceEvent(
              true,
              null,
              null,
              this,
              HookedServiceEvent.updated,
              result: newVal,
              id: oldVal['id'],
              data: newVal,
            ),
          );
        } else if (type == 'remove') {
          // Remove
          hookedService.fireEvent(
            hookedService.afterCreated,
            RethinkDbHookedServiceEvent(
              true,
              null,
              null,
              this,
              HookedServiceEvent.removed,
              result: oldVal,
              id: oldVal['id'],
            ),
          );
        }
      }
      return Future.value();
    }

    feed.listen(onData);
  }

  @override
  Future<List<Map<String, dynamic>>> index([Map? params]) async {
    var query = buildQuery(table, params ?? {});
    return await _sendQuery(query);
  }

  @override
  Future<Map<String, dynamic>> read(String id, [Map? params]) async {
    var query = buildQuery(table.get(id.toString()), params ?? {});
    var found = await _sendQuery(query);
    //print('Found for $id: $found');

    if (found == null) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    } else {
      return found;
    }
  }

  @override
  Future<Map<String, dynamic>> create(Map data, [Map? params]) async {
    if (table is! Table) throw AngelHttpException.methodNotAllowed();

    var d = _serialize(data);
    var q = table as Table;
    var query = buildQuery(q.insert(_squeeze(d)), params ?? {});
    return await _sendQuery(query);
  }

  @override
  Future<Map<String, dynamic>> modify(
    String id,
    Map data, [
    Map? params,
  ]) async {
    var d = _serialize(data);

    if (d is Map && d.containsKey('id')) {
      try {
        await read(d['id'], params);
      } on AngelHttpException catch (e) {
        if (e.statusCode == 404) {
          return await create(data, params);
        } else {
          rethrow;
        }
      }
    }

    var query = buildQuery(table.get(id.toString()), params ?? {}).update(d);
    await _sendQuery(query);
    return await read(id, params);
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map data, [
    Map? params,
  ]) async {
    var d = _serialize(data);

    if (d is Map && d.containsKey('id')) {
      try {
        await read(d['id'], params);
      } on AngelHttpException catch (e) {
        if (e.statusCode == 404) {
          return await create(data, params);
        } else {
          rethrow;
        }
      }
    }

    if (d is Map && !d.containsKey('id')) d['id'] = id.toString();
    var query = buildQuery(table.get(id.toString()), params ?? {}).replace(d);
    await _sendQuery(query);
    return await read(id, params);
  }

  @override
  Future<Map<String, dynamic>> remove(String? id, [Map? params]) async {
    if (id == null ||
        id == 'null' &&
            (allowRemoveAll == true ||
                params?.containsKey('provider') != true)) {
      return await _sendQuery(table.delete());
    } else {
      var prior = await read(id, params);
      var query = buildQuery(table.get(id), params ?? {}).delete();
      await _sendQuery(query);
      return prior;
    }
  }
}

class RethinkDbHookedServiceEvent
    extends HookedServiceEvent<dynamic, dynamic, RethinkService> {
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
