import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart' hide Query;
import 'package:angel3_orm/angel3_orm.dart';

/// A [Service] implementation that wraps over a [Query] class generated
/// via the Angel ORM.
class OrmService<Id, Data, TQuery extends Query<Data, QueryWhere>>
    extends Service<Id, Data>
    implements QueryableService {
  /// The [QueryExecutor] used to communicate with a database.
  final QueryExecutor executor;

  /// A callback that produces an instance of [TQuery].
  final FutureOr<TQuery> Function() queryCreator;

  /// The name of the primary key in the database table.
  ///
  /// Defaults to `'id'`.
  final String idField;

  /// If set to `true`, clients can remove all items by passing a `null` `id` to `remove`.
  ///
  /// `false` by default.
  final bool allowRemoveAll;

  /// If set to `true`, parameters in `req.queryParameters` are applied to the database query.
  final bool allowQuery;

  /// Whether an id, as a client gives it in a path or a query, can be one of
  /// a record, as `isUuid` of a UUID key, so that one that cannot is
  /// refused before a query: a 404 of `read`, `update`, `modify` and
  /// `remove`, a 400 of a query's `id`, and no record of `readMany`. Without
  /// it, every id is queried, and one a column of the database refuses, as a
  /// malformed UUID on PostgreSQL, is the database's error.
  final bool Function(Object id)? validateId;

  /// In most cases, you will want to provide [readData].
  ///
  /// Note that you won't need to call `RequestContext.parseBody`, as by the time
  /// `readData` is invoked, the body will have already been parsed.
  OrmService(
    this.executor,
    this.queryCreator, {
    this.idField = 'id',
    this.allowRemoveAll = false,
    this.allowQuery = true,
    this.validateId,
    super.readData,
  });

  /// `$sort`, one of the query's columns, and one of each column that a
  /// query parameter can match, as `?level=100`, of its type: a number, a
  /// string, a boolean or a date and time. None if [allowQuery] is `false`.
  /// Only `$sort` when [queryCreator] creates the query asynchronously.
  @override
  Map<String, Map<String, dynamic>> get indexQueryParameters {
    if (!allowQuery) return const {};
    var query = queryCreator();
    if (query is! TQuery) {
      return {
        r'$sort': {'type': 'string', 'description': 'The column to sort by'},
      };
    }
    return {
      r'$sort': {
        'type': 'string',
        'enum': query.fields,
        'description': 'The column to sort by',
      },
      for (var builder
          in query.where?.expressionBuilders ?? const <SqlExpressionBuilder>[])
        builder.columnName: ?_schemaOf(builder),
    };
  }

  /// The JSON Schema of a query parameter's value of the column of
  /// [builder], as [_fromString] converts it; `null` of a column that a
  /// query parameter cannot match, as of an enum or JSON.
  static Map<String, dynamic>? _schemaOf(SqlExpressionBuilder builder) =>
      switch (builder) {
        NumericSqlExpressionBuilder<int>() => {'type': 'integer'},
        NumericSqlExpressionBuilder() => {'type': 'number'},
        StringSqlExpressionBuilder() => {'type': 'string'},
        BooleanSqlExpressionBuilder() => {'type': 'boolean'},
        DateTimeSqlExpressionBuilder() => {
          'type': 'string',
          'format': 'date-time',
        },
        _ => null,
      };

  SqlExpressionBuilder _findBuilder(TQuery query, String name) {
    return query.where!.expressionBuilders.firstWhere(
      (b) => b.columnName == name,
      orElse: (() => throw ArgumentError(
        '${query.where.runtimeType} has no expression builder for a column named "$name".',
      )),
    );
  }

  void _apply(TQuery query, String name, dynamic value) {
    if (name == idField && !_isValidId(value)) {
      throw AngelHttpException.badRequest(
        message: 'Invalid value for "$name": $value.',
      );
    }
    var builder = _findBuilder(query, name);
    var typed = value is String ? _fromString(builder, value) : value;
    try {
      (builder as dynamic).equals(typed);
    } on NoSuchMethodError {
      throw UnsupportedError(
        '${builder.runtimeType} has no `equals` method, so it cannot be given a value from the dynamic query parameter "$name".',
      );
    } on TypeError {
      throw AngelHttpException.badRequest(
        message: 'Invalid value for "$name": $value.',
      );
    }
  }

  /// Whether [id] can be that of a record, of [validateId].
  bool _isValidId(Object? id) =>
      id == null || validateId == null || validateId!(id);

  /// The record of [id] of a lookup, as of `read`: a 404 if [validateId]
  /// refuses it.
  void _applyId(TQuery query, Object? id) {
    if (!_isValidId(id)) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    }
    _apply(query, idField, id);
  }

  /// [ids] as a list of the type of the id column of [builder], which `isIn`
  /// requires (e.g. a `List<int>` for an `int` column, even if `Id` is
  /// `int?`).
  static List<Object> _idList(SqlExpressionBuilder builder, List<Object> ids) {
    T convert<T>(Object id, T? Function(String) parse) =>
        id is T ? id as T : parse('$id') ?? (throw _invalidId(id));
    return switch (builder) {
      NumericSqlExpressionBuilder<int>() => <int>[
        for (var id in ids) convert<int>(id, int.tryParse),
      ],
      NumericSqlExpressionBuilder<double>() => <double>[
        for (var id in ids) convert<double>(id, double.tryParse),
      ],
      StringSqlExpressionBuilder() => <String>[for (var id in ids) '$id'],
      _ => ids,
    };
  }

  static AngelHttpException _invalidId(Object id) =>
      AngelHttpException.badRequest(message: 'Invalid id: $id.');

  /// [value], as a query parameter's string, converted to the type of the
  /// column of [builder]; unchanged when it cannot be converted.
  static Object? _fromString(SqlExpressionBuilder builder, String value) =>
      switch (builder) {
        NumericSqlExpressionBuilder<int>() => int.tryParse(value) ?? value,
        NumericSqlExpressionBuilder<double>() =>
          double.tryParse(value) ?? value,
        NumericSqlExpressionBuilder() => num.tryParse(value) ?? value,
        BooleanSqlExpressionBuilder() => switch (value.toLowerCase()) {
          'true' || '1' => true,
          'false' || '0' => false,
          _ => value,
        },
        DateTimeSqlExpressionBuilder() => DateTime.tryParse(value) ?? value,
        _ => value,
      };

  /// Sorts by the column [name], which comes from the client: it is written
  /// into the SQL, so only the query's own columns are accepted.
  void _orderBy(TQuery query, String name, {bool descending = false}) {
    if (!query.fields.contains(name)) {
      throw AngelHttpException.badRequest(
        message: 'Cannot sort by "$name": it is not a column.',
      );
    }
    query.orderBy(name, descending: descending);
  }

  Future<void> _applyQuery(TQuery query, Map<String, dynamic>? params) async {
    if (params == null || params.isEmpty) return;

    if (allowQuery || !params.containsKey('provider')) {
      var queryObj = params['query'];

      if (queryObj is Function(TQuery)) {
        await queryObj(query);
      } else if (queryObj is Map) {
        queryObj.forEach((k, v) {
          if (k == r'$sort') {
            if (v is Map) {
              v.forEach((key, value) {
                var descending = false;
                if (value is String) {
                  descending = value == '-1';
                } else if (value is num) {
                  descending = value.toInt() == -1;
                }
                _orderBy(query, key.toString(), descending: descending);
              });
            } else if (v is String) {
              _orderBy(query, v);
            }
          } else if (k is String &&
              v is! RequestContext &&
              v is! ResponseContext) {
            try {
              _apply(query, k, v);
            } on ArgumentError {
              // A client's query that names no column is a bad request.
              if (!params.containsKey('provider')) rethrow;
              throw AngelHttpException.badRequest(
                message: 'Cannot filter by "$k": it is not a column.',
              );
            }
          }
        });
      }
    }
  }

  @override
  Future<List<Data>> readMany(
    List<Id> ids, [
    Map<String, dynamic>? params,
  ]) async {
    if (ids.isEmpty) {
      throw ArgumentError.value(ids, 'ids', 'cannot be empty');
    }

    var query = await queryCreator();
    var builder = _findBuilder(query, idField);
    // A null id matches no record.
    // A null id, or one that validateId refuses, matches no record.
    var keys = _idList(builder, [
      for (var id in ids)
        if (id != null && _isValidId(id)) id,
    ]);
    if (keys.isEmpty) return [];

    try {
      (builder as dynamic).isIn(keys);
    } on NoSuchMethodError {
      throw UnsupportedError(
        '${builder.runtimeType} `$idField` has no `isIn` method, and therefore does not support `readMany`.',
      );
    }

    await _applyQuery(query, params);
    return await query.get(executor);
  }

  @override
  Future<List<Data>> index([Map<String, dynamic>? params]) async {
    var query = await queryCreator();
    await _applyQuery(query, params);
    return await query.get(executor);
  }

  @override
  Future<Data> read(Id id, [Map<String, dynamic>? params]) async {
    var query = await queryCreator();
    _applyId(query, id);
    await _applyQuery(query, params);
    var result = await query.getOne(executor);
    if (result.isPresent) return result.value;
    throw AngelHttpException.notFound(message: 'No record found for ID $id');
  }

  @override
  Future<Data> findOne([
    Map<String, dynamic>? params,
    String errorMessage = 'No record was found matching the given query.',
  ]) async {
    var query = await queryCreator();
    await _applyQuery(query, params);
    var result = await query.getOne(executor);
    if (result.isPresent) return result.value;
    throw AngelHttpException.notFound(message: errorMessage);
  }

  @override
  Future<Data> create(Data data, [Map<String, dynamic>? params]) async {
    var query = await queryCreator();

    try {
      (query.values as dynamic).copyFrom(data);
    } on NoSuchMethodError {
      throw UnsupportedError(
        '${query.values.runtimeType} has no `copyFrom` method, but OrmService requires this for insertions.',
      );
    }

    // A key of text, as a UUID, is not generated by the database: it is
    // given on each insert, else the insert fails with the database's error.
    var values = query.values;
    if (values is MapQueryValues &&
        values.values[idField] == null &&
        (query.where?.expressionBuilders.any(
              (b) => b.columnName == idField && b is StringSqlExpressionBuilder,
            ) ??
            false)) {
      throw AngelHttpException.badRequest(
        message: 'The "$idField" of the record is required.',
      );
    }
    if (!_isValidId(values is MapQueryValues ? values.values[idField] : null)) {
      throw AngelHttpException.badRequest(
        message: 'Invalid value for "$idField".',
      );
    }

    var result = await query.insert(executor);
    if (result.isPresent) return result.value;
    throw StateError(
      'The record was inserted into ${query.tableName}, but could not be '
      'read back.',
    );
  }

  /// Updates only the fields that are given: for data [readData] read from a
  /// request, those in its body (so a field can still be set to `null`);
  /// otherwise, those that are not `null`. [update] replaces every field.
  @override
  Future<Data> modify(Id id, Data data, [Map<String, dynamic>? params]) {
    return _update(id, data, params, partial: true);
  }

  @override
  Future<Data> update(Id id, Data data, [Map<String, dynamic>? params]) =>
      _update(id, data, params);

  Future<Data> _update(
    Id id,
    Data data,
    Map<String, dynamic>? params, {
    bool partial = false,
  }) async {
    var query = await queryCreator();
    _applyId(query, id);

    // Before the query is applied, so that a query callback can change them.
    try {
      (query.values as dynamic).copyFrom(data);
    } on NoSuchMethodError {
      throw UnsupportedError(
        '${query.values.runtimeType} has no `copyFrom` method, but OrmService requires this for updates.',
      );
    }

    var values = query.values;
    // The record is that of [id]: an id in [data], which `copyFrom` sets of
    // a key the database does not generate (as a UUID), neither changes nor
    // clears its key. A query callback may still set it.
    if (values is MapQueryValues) values.values.remove(idField);
    if (partial && values is MapQueryValues) {
      var given = data is Object && _canRemember(data)
          ? _bodyFields[data]
          : null;
      values.values.removeWhere(
        (name, value) =>
            // Still refreshed by the update.
            name != 'updated_at' &&
            (given == null ? value == null : !given.contains(name)),
      );
      if (values.values.keys.every((name) => name == 'updated_at')) {
        // Nothing to change.
        return read(id, params);
      }
    }

    await _applyQuery(query, params);
    // One record, even if the query's conditions match more.
    query.limit(1);

    var result = await query.updateOne(executor);
    if (result.isPresent) return result.value;
    throw AngelHttpException.notFound(message: 'No record found for ID $id');
  }

  // The fields in the body of the request each object was read from.
  final Expando<Set<String>> _bodyFields = Expando('bodyFields');

  /// Also remembers which fields the request's body contained, so that
  /// [modify] changes only those.
  @override
  FutureOr<Data> Function(RequestContext, ResponseContext)? get readData {
    var read = super.readData;
    if (read == null) return null;
    return (req, res) async {
      var data = await read(req, res);
      if (req.hasParsedBody && data is Object && _canRemember(data)) {
        _bodyFields[data] = req.bodyAsMap.keys.toSet();
      }
      return data;
    };
  }

  // An Expando cannot be attached to these.
  static bool _canRemember(Object data) =>
      data is! num && data is! String && data is! bool && data is! Record;

  @override
  Future<Data> remove(Id id, [Map<String, dynamic>? params]) async {
    var query = await queryCreator();

    if (id == null || id == 'null') {
      // Remove everything...
      if (!(allowRemoveAll == true ||
          params?.containsKey('provider') != true)) {
        throw AngelHttpException.forbidden(
          message: 'Clients are not allowed to delete all items.',
        );
      }
    } else {
      _applyId(query, id);
    }
    // Also when removing "all": only the items that match the query.
    await _applyQuery(query, params);

    var result = await query.deleteOne(executor);
    if (result.isPresent) return result.value;
    throw AngelHttpException.notFound(message: 'No record found for ID $id');
  }
}
