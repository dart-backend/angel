import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:sembast/sembast.dart';

class SembastService extends Service<String, Map<String, dynamic>> {
  final Database database;
  final StoreRef<int, Map<String, dynamic>> store;

  /// If set to `true`, clients can remove all items by passing a `null` `id` to `remove`.
  ///
  /// `false` by default.
  final bool allowRemoveAll;

  /// If set to `true`, parameters in `req.query` are applied to the database query.
  final bool allowQuery;

  SembastService(
    this.database, {
    String? store,
    this.allowRemoveAll = false,
    this.allowQuery = true,
  }) : store = intMapStoreFactory.store(store),
       super();

  Finder? _makeQuery([Map<String, dynamic>? params]) {
    params = Map<String, dynamic>.from(params ?? {});
    var filters = <Filter>[];
    var sort = <SortOrder>[];

    // You can pass a Finder as 'query':
    if (params['query'] is Finder) {
      return params['query'] as Finder?;
    }

    if (allowQuery != true && params.containsKey('provider')) {
      return Finder();
    }

    // `$sort` may be a param of its own, or a field of the query, as it is
    // from the query string of a request.
    var queryObj = params['query'];
    var sortParam =
        params[r'$sort'] ?? (queryObj is Map ? queryObj[r'$sort'] : null);

    if (sortParam is Map) {
      sortParam.forEach((k, sorter) {
        if (sorter is SortOrder) {
          sort.add(sorter);
        } else if (sorter is String || sorter is num) {
          // -1 is descending, anything else ascending.
          var descending = sorter.toString().trim() == '-1';
          sort.add(SortOrder(k.toString(), !descending));
        }
      });
    } else if (sortParam != null) {
      sort.add(SortOrder(sortParam.toString(), true));
    }

    if (queryObj is Map) {
      queryObj.forEach((k, v) {
        if (k != 'provider' &&
            k != r'$sort' &&
            !const ['__requestctx', '__responsectx'].contains(k)) {
          // The id of a record is its key, not a field of its value.
          if (k == 'id') {
            filters.add(Filter.byKey(int.tryParse(v.toString()) ?? v));
          } else {
            filters.add(Filter.equals(k.toString(), v));
          }
        }
      });
    }

    // A record must match every field of the query.
    var filter = switch (filters) {
      [] => null,
      [var only] => only,
      _ => Filter.and(filters),
    };
    return Finder(filter: filter, sortOrders: sort);
  }

  Map<String, dynamic> _withId(Map<String, dynamic> data, String id) =>
      Map<String, dynamic>.from(data)..['id'] = id;

  /// [data] without its `id`, which is the key of the record.
  Map<String, dynamic> _withoutId(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data)..remove('id');

  @override
  Future<Map<String, dynamic>> findOne([
    Map<String, dynamic>? params,
    String errorMessage = 'No record was found matching the given query.',
  ]) async {
    var record = await store.findFirst(database, finder: _makeQuery(params));
    if (record == null) {
      throw AngelHttpException.notFound(message: errorMessage);
    }

    return _withId(record.value, record.key.toString());
  }

  @override
  Future<List<Map<String, dynamic>>> index([
    Map<String, dynamic>? params,
  ]) async {
    var records = await store.find(database, finder: _makeQuery(params));
    return records
        //.where((r) => r.value != null)
        .map((r) => _withId(r.value, r.key.toString()))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> read(
    String id, [
    Map<String, dynamic>? params,
  ]) async {
    var record = await store.record(int.parse(id)).getSnapshot(database);

    if (record == null) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    }

    return _withId(record.value, id);
  }

  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) async {
    return await database.transaction((txn) async {
      data = _withoutId(data);
      var key = await store.add(txn, data);
      var id = key.toString();
      return _withId(data, id);
    });
  }

  @override
  Future<Map<String, dynamic>> modify(
    String id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) async {
    return await database.transaction((txn) async {
      var record = store.record(int.parse(id));
      if (!await record.exists(txn)) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }
      data = await record.put(txn, _withoutId(data), merge: true);
      return _withId(data, id);
    });
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) async {
    return await database.transaction((txn) async {
      var record = store.record(int.parse(id));
      if (!await record.exists(txn)) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }
      data = await record.put(txn, _withoutId(data));
      return _withId(data, id);
    });
  }

  @override
  Future<Map<String, dynamic>> remove(
    String? id, [
    Map<String, dynamic>? params,
  ]) async {
    if (id == null || id == 'null') {
      // Remove everything...
      if (!(allowRemoveAll == true ||
          params?.containsKey('provider') != true)) {
        throw AngelHttpException.forbidden(
          message: 'Clients are not allowed to delete all items.',
        );
      } else {
        // Only the records that match the query, if there is one.
        await store.delete(database, finder: _makeQuery(params));
        return {};
      }
    }

    return database.transaction((txn) async {
      var record = store.record(int.parse(id));
      var snapshot = await record.getSnapshot(txn);

      if (snapshot == null) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      } else {
        await record.delete(txn);
      }

      return _withId(snapshot.value, id);
    });
  }
}
