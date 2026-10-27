import 'dart:async';

import '../angel3_orm.dart';

import 'package:logging/logging.dart';

import 'package:optional/optional.dart';

/// A SQL `SELECT` query builder.
abstract class Query<T, Where extends QueryWhere> extends QueryBase<T> {
  final _log = Logger('Query');

  final List<JoinBuilder> _joins = [];
  final Map<String, int> _names = {};
  final Set<String> _reservedNames = {};
  final List<OrderBy> _orderBy = [];

  // An optional "parent query". If provided, [reserveName] will operate in
  // the parent's context.
  final Query? parent;

  /// A map of field names to explicit SQL expressions. The expressions will be aliased
  /// to the given names.
  final Map<String, String> expressions = {};

  String? _crossJoin, _groupBy;
  int? _limit, _offset;

  Query({this.parent});

  @override
  Map<String, dynamic> get substitutionValues =>
      parent?.substitutionValues ?? super.substitutionValues;

  /// A reference to an abstract query builder.
  ///
  /// This is usually a generated class.
  Where? get where;

  /// A set of values, for an insertion or update.
  ///
  /// This is usually a generated class.
  QueryValues? get values;

  /// Preprends the [tableName] to the [String], [s].
  String adornWithTableName(String s) {
    if (expressions.containsKey(s)) {
      //return '${expressions[s]} AS $s';
      return '(${expressions[s]} AS $s)';
    } else {
      return '$tableName.$s';
    }
  }

  /// Returns a unique version of [name], which will not produce a collision within
  /// the context of this [query].
  String reserveName(String name) {
    if (parent != null) {
      return parent!.reserveName(name);
    }
    // `name`, then `name1`, `name2`, ...; skipping any already reserved
    // (e.g. `name1` reserved for a column of that name).
    var n = _names[name] ?? 0;
    String reserved;
    do {
      reserved = n == 0 ? name : '$name$n';
      n++;
    } while (!_reservedNames.add(reserved));
    _names[name] = n;
    return reserved;
  }

  /// Makes a [Where] clause.
  Where newWhereClause() {
    throw UnsupportedError(
      'This instance does not support creating WHERE clauses.',
    );
  }

  /// Whether [loadRelations] loads relations of the records, such as a
  /// has-many, which are not joined, as they span several rows each.
  bool get loadsRelations => false;

  /// The relations of [records] that are not joined, such as a has-many,
  /// each loaded with a query of its own, for all of [records] at once.
  /// [rows] are those [records] were parsed from, by which they are keyed.
  ///
  /// [loading] are the tables whose records are being loaded, this one's
  /// among them: a relation to one of them is not loaded, as it would load
  /// them again, such as a many-to-many back to this table.
  ///
  /// This is usually generated.
  Future<List<T>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<T> records,
    Set<String> loading,
  ) async => records;

  /// The records of [rows], and the rows they were parsed from.
  (List<List>, List<T>) _parse(List<List> rows) {
    var parsed = <List>[];
    var records = <T>[];
    for (var row in rows) {
      deserialize(row).ifPresent((record) {
        parsed.add(row);
        records.add(record);
      });
    }
    return (parsed, records);
  }

  /// The records of [rows], with their relations ([loadRelations]).
  Future<List<T>> _withRelations(
    QueryExecutor executor,
    List<List> rows, [
    Set<String> loading = const {},
  ]) async {
    var (parsed, records) = _parse(rows);
    if (!loadsRelations || records.isEmpty) return records;
    return loadRelations(executor, parsed, records, {...loading, tableName});
  }

  /// The value of [column] in [row], a row of this query.
  Object? valueOf(String column, List row) {
    var i = fields.indexOf(column);
    if (i == -1 || i >= row.length) {
      throw StateError('$tableName.$column is not selected, so cannot key.');
    }
    return row[i];
  }

  /// A condition that only [getByKeys] sets, as [where] may be the user's.
  String? _keysCondition;

  /// The records of this query whose [column] is one of [keys], with their
  /// relations, by the value of [column], as text, so that a key of a
  /// [Model], a `String`, matches that of the column, an `int`: for a
  /// relation of records being loaded ([loadRelations]).
  Future<Map<String, List<T>>> getByKeys(
    QueryExecutor executor,
    String column,
    Iterable<Object?> keys,
    Set<String> loading,
  ) async {
    var distinct = keys.where((k) => k != null).toSet().toList();
    var byKey = <String, List<T>>{};
    // In parts, as a database binds a limited number of parameters.
    for (var start = 0; start < distinct.length; start += _keysPerQuery) {
      var names = <String>[];
      for (var key in distinct.skip(start).take(_keysPerQuery)) {
        var name = reserveName('${column}_key');
        substitutionValues[name] = key;
        names.add('@$name');
      }
      List<List> rows;
      try {
        _keysCondition =
            '${adornWithTableName(column)} IN (${names.join(', ')})';
        var sql = compile({});
        _log.fine('sql = $sql');
        rows = await executor.query(tableName, sql, substitutionValues);
      } finally {
        _keysCondition = null;
        for (var name in names) {
          substitutionValues.remove(name.substring(1));
        }
      }
      var (parsed, records) = _parse(rows);
      if (loadsRelations && records.isNotEmpty) {
        records = await loadRelations(executor, parsed, records, {
          ...loading,
          tableName,
        });
      }
      for (var (i, record) in records.indexed) {
        var key = '${valueOf(column, parsed[i])}';
        (byKey[key] ??= []).add(record);
      }
    }
    return byKey;
  }

  static const _keysPerQuery = 1000;

  /// For each of [keys], the values of [to] of the rows of [table] whose
  /// [from] is it, by [from], as text: the other ends of a many-to-many.
  static Future<Map<String, List<Object?>>> pivotKeys(
    QueryExecutor executor,
    String table,
    String from,
    String to,
    Iterable<Object?> keys,
  ) async {
    var distinct = keys.where((k) => k != null).toSet().toList();
    var byKey = <String, List<Object?>>{};
    for (var start = 0; start < distinct.length; start += _keysPerQuery) {
      var values = <String, dynamic>{};
      for (var key in distinct.skip(start).take(_keysPerQuery)) {
        values['${from}_key${values.length}'] = key;
      }
      var sql =
          'SELECT $table.$from, $table.$to FROM $table '
          'WHERE $table.$from IN (${values.keys.map((n) => '@$n').join(', ')})';
      for (var row in await executor.query(table, sql, values)) {
        (byKey['${row[0]}'] ??= []).add(row[1]);
      }
    }
    return byKey;
  }

  /// Determines whether this query can be compiled.
  ///
  /// Used to prevent ambiguities in joins.
  bool canCompile(Set<String> trampoline) => true;

  /// Shorthand for calling [where].or with a [Where] clause.
  void andWhere(void Function(Where) f) {
    var w = newWhereClause();
    f(w);
    where?.and(w);
  }

  /// Shorthand for calling [where].or with a [Where] clause.
  void notWhere(void Function(Where) f) {
    var w = newWhereClause();
    f(w);
    where?.not(w);
  }

  /// Shorthand for calling [where].or with a [Where] clause.
  void orWhere(void Function(Where) f) {
    var w = newWhereClause();
    f(w);
    where?.or(w);
  }

  /// Limit the number of rows to return.
  void limit(int n) {
    _limit = n;
  }

  /// Skip a number of rows in the query.
  void offset(int n) {
    _offset = n;
  }

  /// Groups the results by a given key.
  void groupBy(String key) {
    _groupBy = key;
  }

  /// Sorts the results by a key.
  void orderBy(String key, {bool descending = false}) {
    _orderBy.add(OrderBy(key, descending: descending));
  }

  /// Execute a `CROSS JOIN` (Cartesian product) against another table.
  void crossJoin(String tableName) {
    _crossJoin = tableName;
  }

  String _joinAlias(Set<String> trampoline) {
    var i = _joins.length;

    while (true) {
      var a = 'a$i';
      if (trampoline.add(a)) {
        return a;
      } else {
        i++;
      }
    }
  }

  String Function() _compileJoin(Object tableName, Set<String> trampoline) {
    if (tableName is String) {
      return () => tableName;
    } else if (tableName is Query) {
      return () {
        var c = tableName.compile(trampoline);
        //if (c == null) return c;
        if (c == '') {
          return c;
        }
        return '($c)';
      };
    } else {
      _log.severe('$tableName must be a String or Query');
      throw ArgumentError.value(
        tableName,
        'tableName',
        'must be a String or Query',
      );
    }
  }

  void _makeJoin(
    Object tableName,
    Set<String>? trampoline,
    String? alias,
    JoinType type,
    String localKey,
    String foreignKey,
    String op,
    List<String> additionalFields,
  ) {
    trampoline ??= <String>{};

    // Pivot tables guard against ambiguous fields by excluding tables
    // that have already been queried in this scope.
    if (trampoline.contains(tableName) && trampoline.contains(this.tableName)) {
      // ex. if we have {roles, role_users}, then don't join "roles" again.
      return;
    }

    var to = _compileJoin(tableName, trampoline);
    alias ??= _joinAlias(trampoline);
    if (tableName is Query) {
      for (var field in tableName.fields) {
        tableName.aliases[field] = '${alias}_$field';
      }
    }
    _joins.add(
      JoinBuilder(
        type,
        this,
        to,
        localKey,
        foreignKey,
        op: op,
        alias: alias,
        additionalFields: additionalFields,
        aliasAllFields: tableName is Query,
        query: tableName is Query ? tableName : null,
      ),
    );
  }

  /// The names of the columns that the joins of this query add to its rows,
  /// in order: those of each join, then those of the joins of its query.
  List<String> get _joinedColumns => [
    for (var j in _joins) ...[
      ...j.additionalFields.map(j.columnNameFor),
      ...?j.query?._joinedColumns,
    ],
  ];

  /// The columns of [row] that the join at [index], in the order the joins
  /// were made, adds to it, and those of the joins of its query, for that
  /// query to parse; empty if [row] has none.
  List joinedRow(int index, List row) {
    // A SELECT * has no columns of the joins.
    if (fields.isEmpty || index >= _joins.length) return const [];
    var offset = fields.length;
    for (var j in _joins.take(index)) {
      offset +=
          j.additionalFields.length + (j.query?._joinedColumns.length ?? 0);
    }
    var j = _joins[index];
    var end =
        offset +
        j.additionalFields.length +
        (j.query?._joinedColumns.length ?? 0);
    return end <= row.length ? row.sublist(offset, end) : const [];
  }

  /// Execute an `INNER JOIN` against another table.
  void join(
    Object tableName,
    String localKey,
    String foreignKey, {
    String op = '=',
    List<String> additionalFields = const [],
    Set<String>? trampoline,
    String? alias,
  }) {
    _makeJoin(
      tableName,
      trampoline,
      alias,
      JoinType.inner,
      localKey,
      foreignKey,
      op,
      additionalFields,
    );
  }

  /// Execute a `LEFT JOIN` against another table.
  void leftJoin(
    Object tableName,
    String localKey,
    String foreignKey, {
    String op = '=',
    List<String> additionalFields = const [],
    Set<String>? trampoline,
    String? alias,
  }) {
    _makeJoin(
      tableName,
      trampoline,
      alias,
      JoinType.left,
      localKey,
      foreignKey,
      op,
      additionalFields,
    );
  }

  /// Execute a `RIGHT JOIN` against another table.
  void rightJoin(
    Object tableName,
    String localKey,
    String foreignKey, {
    String op = '=',
    List<String> additionalFields = const [],
    Set<String>? trampoline,
    String? alias,
  }) {
    _makeJoin(
      tableName,
      trampoline,
      alias,
      JoinType.right,
      localKey,
      foreignKey,
      op,
      additionalFields,
    );
  }

  /// Execute a `FULL OUTER JOIN` against another table.
  void fullOuterJoin(
    Object tableName,
    String localKey,
    String foreignKey, {
    String op = '=',
    List<String> additionalFields = const [],
    Set<String>? trampoline,
    String? alias,
  }) {
    _makeJoin(
      tableName,
      trampoline,
      alias,
      JoinType.full,
      localKey,
      foreignKey,
      op,
      additionalFields,
    );
  }

  /// Execute a `SELF JOIN`.
  void selfJoin(
    Object tableName,
    String localKey,
    String foreignKey, {
    String op = '=',
    List<String> additionalFields = const [],
    Set<String>? trampoline,
    String? alias,
  }) {
    _makeJoin(
      tableName,
      trampoline,
      alias,
      JoinType.self,
      localKey,
      foreignKey,
      op,
      additionalFields,
    );
  }

  @override
  String compile(
    Set<String> trampoline, {
    bool includeTableName = false,
    String? preamble,
    bool withFields = true,
    String? fromQuery,
  }) => _compile(
    trampoline,
    includeTableName: includeTableName,
    preamble: preamble,
    withFields: withFields,
    fromQuery: fromQuery,
  );

  /// [compile], with [rowsWhere] in place of the conditions set on the
  /// query, when given: the WHERE clause, and LIMIT and OFFSET.
  String _compile(
    Set<String> trampoline, {
    bool includeTableName = false,
    String? preamble,
    bool withFields = true,
    String? fromQuery,
    String? rowsWhere,
  }) {
    // One table MAY appear multiple times in a query.
    if (!canCompile(trampoline)) {
      //return null;
      //throw Exception('One table appear multiple times in a query');
      return '';
    }

    includeTableName = includeTableName || _joins.isNotEmpty;
    var b = StringBuffer(preamble ?? 'SELECT');
    b.write(' ');
    List<String> f;

    var compiledJoins = <JoinBuilder, String?>{};

    //if (fields == null) {
    if (fields.isEmpty) {
      f = ['*'];
    } else {
      f = List<String>.from(
        fields.map((s) {
          String? ss = includeTableName ? '$tableName.$s' : s;
          if (expressions.containsKey(s)) {
            ss = '( ${expressions[s]} )';
            //ss = expressions[s];
          }
          var cast = casts[s];
          if (cast != null) ss = 'CAST ($ss AS $cast)';
          if (aliases.containsKey(s)) {
            if (cast != null) {
              ss = '($ss) AS ${aliases[s]}';
            } else {
              ss = '$ss AS ${aliases[s]}';
            }
            if (expressions.containsKey(s)) {
              // ss = '($ss)';
            }
          } else if (expressions.containsKey(s)) {
            if (cast != null) {
              ss = '($ss) AS $s';
              // ss = '(($ss) AS $s)';
            } else {
              ss = '$ss AS $s';
              // ss = '($ss AS $s)';
            }
          }
          return ss;
        }),
      );
      for (var j in _joins) {
        var c = compiledJoins[j] = j.compile(trampoline);
        //if (c != null) {
        var nested = j.query?._joinedColumns ?? const <String>[];
        if (c != '') {
          var additional = j.additionalFields.map(j.nameFor).toList();
          f.addAll(additional);
          // Those of the joins of its query, which its subquery selects.
          f.addAll(nested.map((name) => '${j.alias}.$name'));
        } else {
          // If compilation failed, fill in NULL placeholders, named as the
          // columns, which a query this one is a subquery of selects.
          for (var name in [
            ...j.additionalFields.map(j.columnNameFor),
            ...nested,
          ]) {
            f.add('NULL AS $name');
          }
        }
      }
    }
    if (withFields) {
      b.write(f.join(', '));
    }
    var whereClause =
        rowsWhere ??
        where?.compile(tableName: includeTableName ? tableName : null);
    var orderByClause = _orderBy.map((order) => order.compile()).join(', ');
    var limits = rowsWhere != null
        ? ''
        : [
            if (_limit != null) ' LIMIT $_limit',
            if (_offset != null) ' OFFSET $_offset',
          ].join();

    var keys = _keysCondition;
    if (keys != null && rowsWhere == null) {
      whereClause = whereClause?.isNotEmpty == true
          ? '($whereClause) AND $keys'
          : keys;
    }

    b.write(' FROM ${fromQuery ?? tableName}');

    // No joins if it's not a select.
    if (preamble == null) {
      if (_crossJoin != null) b.write(' CROSS JOIN $_crossJoin');
      for (var join in _joins) {
        var c = compiledJoins[join];
        if (c != null) b.write(' $c');
      }
    }

    if (whereClause?.isNotEmpty == true) {
      b.write(' WHERE $whereClause');
    }
    if (_groupBy != null) b.write(' GROUP BY $_groupBy');
    if (orderByClause.isNotEmpty) {
      b.write(' ORDER BY $orderByClause');
    }
    b.write(limits);
    return b.toString();
  }

  /// The matching records, with their relations ([loadRelations]).
  @override
  Future<List<T>> get(QueryExecutor executor) async {
    var sql = compile({});
    _log.fine('sql = $sql');
    _log.fine('values = $substitutionValues');
    return _withRelations(
      executor,
      await executor.query(tableName, sql, substitutionValues),
    );
  }

  /// The first matching record. Only one row is fetched, as a record spans
  /// one: the relations of several rows each are loaded on their own.
  @override
  Future<Optional<T>> getOne(QueryExecutor executor) async {
    if (_limit != null) return super.getOne(executor);
    _limit = 1;
    try {
      return await super.getOne(executor);
    } finally {
      _limit = null;
    }
  }

  Future<List<T>> delete(QueryExecutor executor) {
    var sql = compile({}, preamble: 'DELETE', withFields: false);

    if (executor.dialect is PostgreSQLDialect) {
      var returning = fields.map(adornWithTableName).join(', ');
      var selectSQL = compile({});
      sql = 'WITH $tableName as ($sql RETURNING $returning) $selectSQL';
    }

    _log.fine("Delete Query = $sql");
    _log.fine("Substritution Values = $substitutionValues");

    // MySQL has no RETURNING: the rows are selected first, in a transaction.
    // Its relations are loaded before it is deleted, as they may be with it.
    if (_joins.isEmpty &&
        !loadsRelations &&
        executor.dialect is PostgreSQLDialect) {
      return executor
          .query(
            tableName,
            sql,
            substitutionValues,
            returningFields: fields.map(adornWithTableName).toList(),
          )
          .then((it) => deserializeList(it));
    } else {
      return executor.transaction((tx) async {
        // TODO: Can this be done with just *one* query?
        var existing = await get(tx);

        return tx
            .query(tableName, sql, substitutionValues)
            .then((_) => existing);
      });
    }
  }

  Future<Optional<T>> deleteOne(QueryExecutor executor) {
    return delete(executor).then(
      (it) =>
          it.isEmpty == true ? Optional.empty() : Optional.ofNullable(it.first),
    );
  }

  /// Inserts into a table without an id on MySQL or MariaDB with [sql], and
  /// returns the row of the values inserted, as MySQL returns no row, and one
  /// of no key cannot be selected again by its values: a `DATETIME` drops
  /// the fraction of a second of one, and a `NULL` equals none. A column not
  /// given is null, not the default of the database.
  Future<Optional<T>> _insertWithoutId(
    QueryExecutor executor,
    String sql,
  ) async {
    _log.fine("Insert Query = $sql");
    await executor.query(tableName, sql, substitutionValues);
    return _first(
      _withRelations(executor, [
        [for (var field in fields) _boundValue(field)],
      ]),
    );
  }

  /// The value bound to [column] by the values of the query, as an insert or
  /// an update binds it, or `null` if none is.
  Object? _boundValue(String column, [Object? otherwise]) {
    var name = values?.parameterNameOf(this, column);
    return name != null && substitutionValues.containsKey(name)
        ? substitutionValues[name]
        : otherwise;
  }

  Future<Optional<T>> insert(QueryExecutor executor) {
    var insertion = values?.compileInsert(this, tableName);

    if (insertion == '') {
      throw StateError('No values have been specified for insertion.');
    } else {
      var returningSql = '';
      var sql = '$insertion';
      if (executor.dialect is PostgreSQLDialect) {
        var returning = fields.map(adornWithTableName).join(', ');
        var selectSQL = compile({});
        sql = 'WITH $tableName as ($insertion RETURNING $returning) $selectSQL';
        //sql = 'WITH $tableName as ($insertion RETURNING $returning)';
      } else if (executor.dialect is MySQLDialect) {
        // Default to using 'id' as primary key in model
        if (fields.contains("id")) {
          var selectSQL = compile({});

          // The row of the id given, by its parameter, as the database
          // gives no insert id of a key it does not generate, such as a
          // UUID; or else of the id the database gave it, of the placeholder
          // [insertIdParameter] that the executor binds to its insert id, not
          // the last row by id, which may be of another connection's insert.
          var idName = values?.toMap()['id'] == null
              ? null
              : values?.parameterNameOf(this, 'id');
          returningSql =
              '$selectSQL where $tableName.id=@${idName ?? insertIdParameter}';
        } else {
          return _insertWithoutId(executor, sql);
        }
      } else {
        throw ArgumentError("Unsupported database dialect.");
      }

      _log.fine("Insert Query = $sql");
      _log.fine("Substritution Values = $substitutionValues");

      return executor
          .query(
            tableName,
            sql,
            substitutionValues,
            returningFields: fields,
            returningQuery: returningSql,
          )
          .then(
            (result) =>
                _first(_withRelations(executor, result.take(1).toList())),
          );
    }
  }

  /// Updates the rows that match [where] (at most [limit] of them, after
  /// [offset]) with [values], and returns them as updated.
  Future<List<T>> update(QueryExecutor executor) async {
    var valuesClause = values?.compileForUpdate(this);
    if (valuesClause == null || valuesClause == '') {
      throw StateError('No values have been specified for update.');
    }
    var whereClause = where?.compile() ?? '';
    var conditions = whereClause.isEmpty ? '' : ' WHERE $whereClause';
    var limits = [
      if (_limit != null) ' LIMIT $_limit',
      if (_offset != null) ' OFFSET $_offset',
    ].join();

    if (executor.dialect is PostgreSQLDialect) {
      // PostgreSQL has no UPDATE ... LIMIT: the rows are picked by ctid.
      var rows = limits.isEmpty
          ? conditions
          : ' WHERE ctid IN (SELECT ctid FROM $tableName$conditions$limits)';
      var returning = fields.map(adornWithTableName).join(', ');
      // The updated rows, as RETURNING gives them: not filtered by the
      // conditions again, which their new values may no longer match.
      var select = _compile({}, rowsWhere: '');
      var sql =
          'WITH $tableName as (UPDATE $tableName $valuesClause$rows '
          'RETURNING $returning) $select';
      _log.fine("Update Query = $sql");
      _log.fine("Substitution Values = $substitutionValues");
      return _withRelations(
        executor,
        await executor.query(tableName, sql, substitutionValues),
      );
    }

    if (executor.dialect is! MySQLDialect) {
      throw ArgumentError("Unsupported database dialect.");
    }

    if (!fields.contains('id')) {
      // Without a primary key, the rows that match are selected first, in a
      // transaction, and returned with the values they are updated to, as
      // their new values may no longer match the conditions.
      var select = compile({});
      var sql = 'UPDATE $tableName $valuesClause$conditions$limits';
      _log.fine("Update Query = $sql");
      return executor.transaction((tx) async {
        var rows = await tx.query(tableName, select, substitutionValues);
        await tx.query(tableName, sql, substitutionValues);
        return _withRelations(tx, [
          for (var row in rows)
            [
              for (var (i, field) in fields.indexed)
                _boundValue(field, i < row.length ? row[i] : null),
            ],
        ]);
      });
    }

    // MySQL has no RETURNING: find the rows first, then update and select
    // exactly those, by id.
    var found = await executor.query(
      tableName,
      'SELECT id FROM $tableName$conditions$limits',
      substitutionValues,
    );
    if (found.isEmpty) return [];
    var ids = [
      for (var row in found)
        if (row.first is int) '${row.first}' else '@${_bindId(row.first)}',
    ].join(', ');

    var sql = 'UPDATE $tableName $valuesClause WHERE id IN ($ids)';
    _log.fine("Update Query = $sql");
    _log.fine("Substitution Values = $substitutionValues");
    await executor.query(tableName, sql, substitutionValues);
    return _withRelations(
      executor,
      await executor.query(
        tableName,
        _compile({}, rowsWhere: '${adornWithTableName('id')} IN ($ids)'),
        substitutionValues,
      ),
    );
  }

  Future<Optional<T>> _first(Future<List<T>> records) => records.then(
    (it) => it.isEmpty ? Optional.empty() : Optional.of(it.first),
  );

  /// Binds a primary key that is not an int (e.g. a UUID) as a parameter.
  String _bindId(Object? id) {
    var name = reserveName('id');
    substitutionValues[name] = id;
    return name;
  }

  Future<Optional<T>> updateOne(QueryExecutor executor) {
    return update(executor).then(
      (it) => it.isEmpty ? Optional.empty() : Optional.ofNullable(it.first),
    );
  }
}
