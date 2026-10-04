import 'dart:async';

import 'package:angel3_http_exception/angel3_http_exception.dart';

import 'service.dart';

/// A basic service that manages an in-memory list of maps.
class MapService extends Service<String?, Map<String, dynamic>> {
  /// If set to `true`, clients can remove all items by passing a `null` `id` to `remove`.
  ///
  /// `false` by default.
  final bool allowRemoveAll;

  /// If set to `true`, parameters in `req.query` are applied to the database query.
  final bool allowQuery;

  /// If set to `true` (default), then the service will manage an `id` string and `createdAt` and `updatedAt` fields.
  final bool autoIdAndDateFields;

  /// If set to `true` (default), then the keys `created_at` and `updated_at` will automatically be snake_cased.
  final bool autoSnakeCaseNames;

  final List<Map<String, dynamic>> items = [];

  int _idCounter = 0;

  MapService({
    this.allowRemoveAll = false,
    this.allowQuery = true,
    this.autoIdAndDateFields = true,
    this.autoSnakeCaseNames = true,
  }) : super();

  String get createdAtKey =>
      autoSnakeCaseNames == false ? 'createdAt' : 'created_at';

  String get updatedAtKey =>
      autoSnakeCaseNames == false ? 'updatedAt' : 'updated_at';

  /// Returns an id not used by any item, even after removals or when
  /// [items] has been populated directly.
  String _nextId() {
    String id;
    do {
      id = (_idCounter++).toString();
    } while (items.any(_matchesId(id)));
    return id;
  }

  bool Function(Map<String, dynamic>) _matchesId(Object? id) {
    return (Map<String, dynamic> item) {
      if (item['id'] == null) {
        return false;
      } else if (autoIdAndDateFields != false) {
        return item['id'] == id.toString();
      } else {
        return item['id'] == id;
      }
    };
  }

  /// Returns the items matching `params['query']`, sorted by `$sort` and
  /// truncated to `$limit`.
  ///
  /// `$sort` is a field name (ascending) or a map of field names to `1`
  /// (ascending) or `-1` (descending); `$limit` is a non-negative count.
  /// Both may be given in `params` (server-side calls) or in the query (REST,
  /// e.g. `?$sort=text&$limit=10`). Keys in [Service.specialQueryKeys] are
  /// never used as filters. Query values that are strings, as they always
  /// are over REST, also match non-string fields with the same string form,
  /// so `?done=false` matches `false`.
  ///
  /// When [allowQuery] is `false`, the query (including its `$sort` and
  /// `$limit`) is ignored.
  @override
  Future<List<Map<String, dynamic>>> index([Map<String, dynamic>? params]) {
    var query = allowQuery != false && params?['query'] is Map
        ? params!['query'] as Map
        : const {};

    var result = items.where((item) {
      for (var key in query.keys) {
        if (Service.specialQueryKeys.contains(key)) continue;
        if (!item.containsKey(key) || !_valueMatches(item[key], query[key])) {
          return false;
        }
      }
      return true;
    }).toList();

    var sort = params?[r'$sort'] ?? query[r'$sort'];
    if (sort != null) _sort(result, sort);

    var limit = _parseLimit(params?[r'$limit'] ?? query[r'$limit']);
    if (limit != null && limit < result.length) {
      result = result.sublist(0, limit);
    }

    return Future.value(result);
  }

  static bool _valueMatches(Object? value, Object? expected) {
    if (value == expected) return true;
    return expected is String &&
        value != null &&
        value is! String &&
        value.toString() == expected;
  }

  static int? _parseLimit(Object? limit) {
    var n = limit is int ? limit : int.tryParse(limit?.toString() ?? '');
    if (limit != null && (n == null || n < 0)) {
      throw AngelHttpException.badRequest(
        message: r'$limit must be a non-negative integer.',
      );
    }
    return n;
  }

  static void _sort(List<Map<String, dynamic>> items, Object sort) {
    // (field, descending) pairs, applied in order.
    var fields = <(String, bool)>[];
    if (sort is Map) {
      sort.forEach((field, direction) {
        fields.add((field.toString(), direction == -1 || direction == '-1'));
      });
    } else {
      fields.add((sort.toString(), false));
    }

    int compare(Object? a, Object? b) {
      if (a == null || b == null) {
        // Missing values sort last.
        return a == null ? (b == null ? 0 : 1) : -1;
      }
      if (a is Comparable && a.runtimeType == b.runtimeType) {
        return a.compareTo(b);
      }
      if (a is num && b is num) return a.compareTo(b);
      return a.toString().compareTo(b.toString());
    }

    // List.sort is not stable, so break ties by original position.
    var indexed = items.indexed.toList();
    indexed.sort((x, y) {
      for (var (field, descending) in fields) {
        var c = compare(x.$2[field], y.$2[field]);
        if (c != 0) return descending ? -c : c;
      }
      return x.$1.compareTo(y.$1);
    });
    items
      ..clear()
      ..addAll(indexed.map((e) => e.$2));
  }

  @override
  Future<Map<String, dynamic>> read(
    String? id, [
    Map<String, dynamic>? params,
  ]) {
    // Future.sync, so a missing id fails the returned future rather than
    // throwing synchronously.
    return Future.sync(
      () => items.firstWhere(
        _matchesId(id),
        orElse: (() => throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        )),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) {
    var now = DateTime.now().toIso8601String();
    var result = Map<String, dynamic>.from(data);

    if (autoIdAndDateFields == true) {
      result
        ..['id'] = _nextId()
        ..[autoSnakeCaseNames == false ? 'createdAt' : 'created_at'] = now
        ..[autoSnakeCaseNames == false ? 'updatedAt' : 'updated_at'] = now;
    }
    items.add(result);
    return Future.value(result);
  }

  @override
  Future<Map<String, dynamic>> modify(
    String? id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) {
    //if (data is! Map) {
    //  throw AngelHttpException.badRequest(
    //      message:
    //          'MapService does not support `modify` with ${data.runtimeType}.');
    //}
    // A missing id is a 404 (via read): patching cannot create a record.
    return read(id).then((item) {
      var idx = items.indexOf(item);
      if (idx < 0) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }
      var result = Map<String, dynamic>.from(item)..addAll(data);

      if (autoIdAndDateFields == true) {
        result[autoSnakeCaseNames == false ? 'updatedAt' : 'updated_at'] =
            DateTime.now().toIso8601String();
      }
      return Future.value(items[idx] = result);
    });
  }

  @override
  Future<Map<String, dynamic>> update(
    String? id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) {
    //if (data is! Map) {
    //  throw AngelHttpException.badRequest(
    //      message:
    //          'MapService does not support `update` with ${data.runtimeType}.');
    //}
    if (!items.any(_matchesId(id))) return Future.value(_insertAt(id, data));

    return read(id).then((old) {
      if (!items.remove(old)) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }

      var result = Map<String, dynamic>.from(data);
      if (autoIdAndDateFields == true) {
        result
          ..['id'] = id?.toString()
          ..[autoSnakeCaseNames == false ? 'createdAt' : 'created_at'] =
              old[autoSnakeCaseNames == false ? 'createdAt' : 'created_at']
          ..[autoSnakeCaseNames == false ? 'updatedAt' : 'updated_at'] =
              DateTime.now().toIso8601String();
      }
      items.add(result);
      return Future.value(result);
    });
  }

  /// Creates a record with the given [id], as `PUT` to a missing id does.
  Map<String, dynamic> _insertAt(String? id, Map<String, dynamic> data) {
    if (id == null || id == 'null' || id.isEmpty) {
      throw AngelHttpException.badRequest(message: 'Invalid ID "$id".');
    }

    var result = Map<String, dynamic>.from(data);
    if (autoIdAndDateFields == true) {
      var now = DateTime.now().toIso8601String();
      result
        ..['id'] = id
        ..[createdAtKey] = now
        ..[updatedAtKey] = now;
    } else {
      // Like create(), leave the client's fields alone; only make sure the
      // record can be found again.
      result.putIfAbsent('id', () => id);
    }
    items.add(result);
    return result;
  }

  @override
  Future<Map<String, dynamic>> remove(
    String? id, [
    Map<String, dynamic>? params,
  ]) {
    if (id == null || id == 'null') {
      // Remove everything...
      if (!(allowRemoveAll == true ||
          params?.containsKey('provider') != true)) {
        throw AngelHttpException.forbidden(
          message: 'Clients are not allowed to delete all items.',
        );
      } else {
        items.clear();
        return Future.value({});
      }
    }

    return read(id, params).then((result) {
      if (items.remove(result)) {
        return result;
      } else {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }
    });
  }
}
