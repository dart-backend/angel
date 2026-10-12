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
        if (params[key] is Map) {
          // If they send a map, then we'll sort by every key in the map

          for (var fieldName in params[key].keys.where((x) => x is String)) {
            var sorter = params[key][fieldName];
            if (sorter is num && fieldName is String) {
              result = result.sortBy(fieldName, descending: sorter == -1);
            } else if (sorter is String && fieldName is String) {
              result = result.sortBy(fieldName, descending: sorter == '-1');
            } else if (sorter is SelectorBuilder) {
              result = result.and(sorter);
            }
          }
        } else if (params[key] is String && key == r'$sort') {
          // If they send just a string, then we'll sort
          // by that, ascending
          result = result.sortBy(params[key] as String);
        }
      } else if (key == 'query' && useQuery) {
        var query = params[key] as Map?;
        query?.forEach((key, v) {
          var value = v is Map<String, dynamic> ? _filterNoQuery(v) : v;

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
