part of 'services.dart';

/// Manipulates data from MongoDB as Maps.
class MongoService extends Service<String, Map<String, dynamic>> {
  DbCollection collection;

  /// If set to `true`, clients can remove all items by passing a `null` `id` to `remove`.
  ///
  /// `false` by default.
  final bool allowRemoveAll;

  /// If set to `true`, parameters in `req.query` are applied to the database query.
  final bool allowQuery;

  MongoService(
    this.collection, {
    this.allowRemoveAll = false,
    this.allowQuery = true,
  }) : super();

  SelectorBuilder? _makeQuery([Map<String, dynamic>? params_]) {
    var params = Map.from(params_ ?? {});
    // A request from a client; checked before 'provider' is removed.
    var fromClient = params.remove('provider') != null;
    var useQuery = allowQuery == true || !fromClient;
    var result = where.exists('_id');

    // You can pass a SelectorBuilder as 'query';
    if (params['query'] is SelectorBuilder) {
      return params['query'] as SelectorBuilder?;
    }

    for (var key in params.keys) {
      if ((key == r'$sort' || key == r'$query') && useQuery) {
        result = _sort(result, params[key]);
      } else if (key == r'$limit' && useQuery) {
        result = _limit(result, params[key]);
      } else if (key == 'query' && useQuery && params[key] is Map) {
        var query = params[key] as Map;
        query.forEach((key, v) {
          // In a query string, `$sort` and `$limit` sort and limit; the
          // other special keys (e.g. an auth `token`) are not filters.
          if (key == r'$sort') {
            result = _sort(result, v);
            return;
          } else if (key == r'$limit') {
            result = _limit(result, v);
            return;
          } else if (Service.specialQueryKeys.contains(key)) {
            return;
          }

          var value = v is Map
              ? _filterNoQuery(Map<String, dynamic>.from(v))
              : v;

          if (!_noQuery.contains(key) &&
              value is! RequestContext &&
              value is! ResponseContext) {
            result = result.and(where.eq(key as String, value));
          }
        });
      }
    }

    return result;
  }

  /// Applies a `$sort`: a map of field names to `1` (ascending) or `-1`
  /// (descending), or, as a query string sends it, field names separated by
  /// commas, each descending if it starts with `-` (`?$sort=-createdAt,to`).
  static SelectorBuilder _sort(SelectorBuilder result, Object? sort) {
    if (sort is Map) {
      for (var fieldName in sort.keys.whereType<String>()) {
        var sorter = sort[fieldName];
        if (sorter is num) {
          result = result.sortBy(fieldName, descending: sorter == -1);
        } else if (sorter is String) {
          result = result.sortBy(fieldName, descending: sorter == '-1');
        } else if (sorter is SelectorBuilder) {
          result = result.and(sorter);
        }
      }
    } else if (sort is String) {
      for (var field in sort.split(',').map((f) => f.trim())) {
        var descending = field.startsWith('-');
        if (descending) field = field.substring(1);
        if (field.isNotEmpty) {
          result = result.sortBy(field, descending: descending);
        }
      }
    }
    return result;
  }

  /// Applies a `$limit`, a non-negative count; anything else is a 400.
  static SelectorBuilder _limit(SelectorBuilder result, Object? limit) {
    var n = limit is int ? limit : int.tryParse(limit?.toString() ?? '');
    if (n == null || n < 0) {
      throw AngelHttpException.badRequest(
        message: r'$limit must be a non-negative integer.',
      );
    }
    return result.limit(n);
  }

  Map<String, dynamic> _jsonify(
    Map<String, dynamic> doc, [
    Map<String, dynamic>? params,
  ]) {
    var result = <String, dynamic>{};

    for (var key in doc.keys) {
      var value = doc[key];
      if (value is ObjectId) {
        result[key] = value.oid;
      } else if (value is! RequestContext && value is! ResponseContext) {
        result[key] = value;
      }
    }

    return _transformId(result);
  }

  @override
  Future<List<Map<String, dynamic>>> index([
    Map<String, dynamic>? params,
  ]) async {
    return await (collection.find(_makeQuery(params)))
        .map((x) => _jsonify(x, params))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) async {
    // The service manages the id and timestamps, so a client cannot set them.
    var now = DateTime.now().toIso8601String();
    var item = _removeSensitive(data)
      ..['createdAt'] = now
      ..['updatedAt'] = now;

    try {
      var result = await collection.insertOne(item);
      return _jsonify(result.document ?? item);
    } catch (e, st) {
      throw AngelHttpException(error: e, stackTrace: st);
    }
  }

  @override
  Future<Map<String, dynamic>> findOne([
    Map<String, dynamic>? params,
    String errorMessage = 'No record was found matching the given query.',
  ]) async {
    var found = await collection.findOne(_makeQuery(params));

    if (found == null) {
      throw AngelHttpException.notFound(message: errorMessage);
    }

    return _jsonify(found, params);
  }

  @override
  Future<Map<String, dynamic>> read(
    String id, [
    Map<String, dynamic>? params,
  ]) async {
    var localId = _makeId(id);
    var found = await collection.findOne(
      where.id(localId).and(_makeQuery(params)!),
    );

    if (found == null) {
      throw AngelHttpException.notFound(
        message: 'No record found for ID ${localId.oid}',
      );
    }

    return _jsonify(found, params);
  }

  @override
  Future<List<Map<String, dynamic>>> readMany(
    List<String> ids, [
    Map<String, dynamic>? params,
  ]) async {
    var oids = ids.map(_makeId).toList();
    var q = _makeQuery(params)!.and(where.oneFrom('_id', oids));
    return await (collection.find(q)).map((x) => _jsonify(x, params)).toList();
  }

  /// The stored document with [id], without its `_id`; throws a 404 if none.
  Future<Map<String, dynamic>> _findRaw(ObjectId id) async {
    var found = await collection.findOne(where.id(id));
    if (found == null) {
      throw AngelHttpException.notFound(
        message: 'No record found for ID ${id.oid}',
      );
    }
    return found..remove('_id');
  }

  /// Merges [data] into the document with [id]. A patch cannot create a
  /// document, so a missing [id] is a 404.
  @override
  Future<Map<String, dynamic>> modify(
    String id,
    data, [
    Map<String, dynamic>? params,
  ]) async {
    var oid = _makeId(id);
    var current = await _findRaw(oid);

    // `id` is left out: it is only added for clients, and older versions
    // stored it by mistake.
    var updatedDoc = mergeMap([current, _removeSensitive(data)])
      ..remove('id')
      ..['createdAt'] = current['createdAt']
      ..['updatedAt'] = DateTime.now().toIso8601String();
    if (updatedDoc['createdAt'] == null) updatedDoc.remove('createdAt');

    try {
      var modified = await collection.findAndModify(
        query: where.id(oid),
        update: updatedDoc,
        returnNew: true,
      );
      if (modified == null) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }
      return _jsonify(modified, params);
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      throw AngelHttpException(error: e, stackTrace: st);
    }
  }

  /// Replaces the document with [id], creating it if missing.
  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) async {
    var oid = _makeId(id);
    var now = DateTime.now().toIso8601String();
    var existing = await collection.findOne(where.id(oid));
    var updatedDoc = _removeSensitive(data)
      ..['createdAt'] = existing?['createdAt'] ?? now
      ..['updatedAt'] = now;

    try {
      var updated = await collection.findAndModify(
        query: where.id(oid),
        update: updatedDoc,
        returnNew: true,
        upsert: true,
      );
      return _jsonify(updated ?? {'_id': oid, ...updatedDoc}, params);
    } catch (e, st) {
      throw AngelHttpException(error: e, stackTrace: st);
    }
  }

  /// Removes the document with [id] and returns it; a missing [id] is a 404.
  ///
  /// With the id `'null'`, removes every document matching the query
  /// instead; clients may only do that if [allowRemoveAll] is `true`.
  @override
  Future<Map<String, dynamic>> remove(
    String id, [
    Map<String, dynamic>? params,
  ]) async {
    if (id == 'null') {
      if (allowRemoveAll != true && params?.containsKey('provider') == true) {
        throw AngelHttpException.forbidden(
          message: 'Clients are not allowed to delete all items.',
        );
      }
      await collection.deleteMany(_makeQuery(params));
      return {};
    }

    var oid = _makeId(id);
    Map<String, dynamic>? removed;
    try {
      removed = await collection.findAndModify(
        query: where.id(oid),
        remove: true,
      );
    } catch (e, st) {
      throw AngelHttpException(error: e, stackTrace: st);
    }
    if (removed == null) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    }
    return _jsonify(removed, params);
  }
}
