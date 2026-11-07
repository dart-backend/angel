import 'dart:async';

import '../angel3_orm.dart';
import 'identifier.dart';

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
      return '(${expressions[s]})';
    } else {
      return '$tableName.$s';
    }
  }

  /// What a `RETURNING` clause returns: every column of the table, as the
  /// select around it computes [fields], and may name any of them, in its
  /// order, joins or [expressions].
  String get _returning => '$tableName.*';

  /// The `ORDER BY` clause, with a leading space, if it has one.
  String get _orderByClause {
    if (_orderBy.isEmpty) return '';
    return ' ORDER BY ${_orderBy.map((order) => order.compile()).join(', ')}';
  }

  /// The `ORDER BY` clause of [_selectOf], with a leading space, if it has one:
  /// with the SQL of an expression, as it selects no alias of it.
  String get _orderByOfRows {
    if (_orderBy.isEmpty) return '';
    var orders = [
      for (var order in _orderBy)
        if (_columnOfOrder(order.key) case var column?)
          '$column ${order.descending ? 'DESC' : 'ASC'}'
        else
          order.compile(),
    ];
    return ' ORDER BY ${orders.join(', ')}';
  }

  /// The SQL that an order by [key] sorts by in [compile], where it names a
  /// column that the query selects, which [_selectOf] does not, or else `null`:
  /// of an alias, an expression, or a column that a join may have too.
  String? _columnOfOrder(String key) {
    var field = key;
    for (var entry in aliases.entries) {
      if (entry.value == key) field = entry.key;
    }
    if (expressions[field] case var expression?) return '($expression)';
    if (field == key && (!_isJoined || !fields.contains(field))) {
      return null;
    }
    return _isJoined ? '$tableName.$field' : field;
  }

  /// A select of [columns] of this table, of the rows a [limit] picks: with
  /// the joins, conditions and order of this query, as in [compile], by which
  /// an order may name a join.
  String _selectOf(List<String> columns) {
    var selected = [
      for (var column in columns) _isJoined ? '$tableName.$column' : column,
    ];
    return _compile(
      {},
      selecting: selected.join(', '),
      existing: selected.first,
    );
  }

  /// Whether this query joins another table, of any kind.
  bool get _isJoined => _joins.isNotEmpty || _crossJoin != null;

  /// Whether a join can leave a row of this table out: all but a `LEFT JOIN`.
  bool get _leavesRowsOut =>
      _crossJoin != null || _joins.any((j) => j.type != JoinType.left);

  /// Whether a join can give rows of no row of this table, of `NULL` columns.
  bool get _addsRows =>
      _joins.any((j) => j.type == JoinType.right || j.type == JoinType.full);

  /// The name of the `WITH` clause of a statement that writes, which is not of
  /// the table, as it would hide the table from the select around it, such as
  /// from a join of the table with itself.
  static const _written = 'angel3_written';

  /// The select of the rows that a statement in the `WITH` clause [_written]
  /// wrote, as its `RETURNING` gives them: not filtered by the conditions
  /// again, which their new values may no longer match, nor limited again.
  String get _writtenRows => _compile(
    {},
    rowsWhere: '',
    fromQuery: '$_written AS $tableName',
    written: true,
  );

  /// The `LIMIT` and `OFFSET` clauses, with a leading space, if it has them.
  String get _limits => [
    if (_limit != null) ' LIMIT $_limit',
    if (_offset != null) ' OFFSET $_offset',
  ].join();

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
        _log.fine(() => 'sql = $sql');
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

  /// Groups the results by a given key: a column, or several separated by
  /// commas. An expression is not accepted, as the key is written into the SQL.
  void groupBy(String key) {
    for (var column in key.split(',')) {
      checkIdentifier(column.trim(), 'key', 'GROUP BY column');
    }
    _groupBy = key;
  }

  /// Sorts the results by a key.
  void orderBy(String key, {bool descending = false}) {
    _orderBy.add(OrderBy(key, descending: descending));
  }

  /// Execute a `CROSS JOIN` (Cartesian product) against another table.
  void crossJoin(String tableName) {
    _crossJoin = checkIdentifier(tableName, 'tableName', 'CROSS JOIN table');
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

  static const _joinOperators = {'=', '!=', '<>', '<', '<=', '>', '>='};

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
    // All of these are written into the SQL as they are.
    if (tableName is String) {
      checkIdentifier(tableName, 'tableName', 'JOIN table');
    }
    checkName(localKey, 'localKey', 'JOIN column');
    // The columns of a query joined are named after its alias (`a0_name`).
    var checkJoined = tableName is Query ? checkPlainName : checkName;
    checkJoined(foreignKey, 'foreignKey', 'JOIN column');
    if (alias != null) checkJoined(alias, 'alias', 'JOIN alias');
    for (var field in additionalFields) {
      checkJoined(field, 'additionalFields', 'JOIN column');
    }
    if (!_joinOperators.contains(op)) {
      throw ArgumentError.value(
        op,
        'op',
        'must be one of ${_joinOperators.join(' ')}',
      );
    }

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
    String? selecting,
    String? existing,
    String lock = '',
    bool written = false,
  }) {
    // One table MAY appear multiple times in a query.
    if (!canCompile(trampoline)) {
      //return null;
      //throw Exception('One table appear multiple times in a query');
      return '';
    }

    includeTableName = includeTableName || _isJoined;
    var b = StringBuffer(preamble ?? 'SELECT');
    b.write(' ');
    List<String> f;

    var compiledJoins = <JoinBuilder, String?>{};

    //if (fields == null) {
    if (fields.isEmpty) {
      // Only the columns of this table, as [joinedRow] expects of a SELECT *.
      f = [_isJoined ? '$tableName.*' : '*'];
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
    }
    for (var j in _joins) {
      // Of rows that were written, each is returned, whatever it now joins.
      var c = compiledJoins[j] = j.compile(trampoline, leftJoin: written);
      if (fields.isEmpty) continue;
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
    if (withFields) {
      b.write(selecting ?? f.join(', '));
    }
    var whereClause =
        rowsWhere ??
        where?.compile(tableName: includeTableName ? tableName : null);
    var limits = rowsWhere != null ? '' : _limits;

    var keys = _keysCondition;
    if (keys != null && rowsWhere == null) {
      whereClause = whereClause?.isNotEmpty == true
          ? '($whereClause) AND $keys'
          : keys;
    }
    // Only rows of this table, which [existing] is never `NULL` in, as a join
    // adds others, which a limit would count.
    if (existing != null && _addsRows) {
      whereClause = whereClause?.isNotEmpty == true
          ? '($whereClause) AND $existing IS NOT NULL'
          : '$existing IS NOT NULL';
    }

    b.write(' FROM ${fromQuery ?? tableName}');

    // No joins if it's not a select.
    if (preamble == null) {
      if (_crossJoin != null && !written) {
        b.write(' CROSS JOIN $_crossJoin');
      }
      for (var join in _joins) {
        var c = compiledJoins[join];
        if (c != null) b.write(' $c');
      }
    }

    if (whereClause?.isNotEmpty == true) {
      b.write(' WHERE $whereClause');
    }
    if (_groupBy != null && selecting == null) {
      b.write(' GROUP BY $_groupBy');
    }
    b.write(selecting == null ? _orderByClause : _orderByOfRows);
    b.write(limits);
    b.write(lock);
    return b.toString();
  }

  @override
  Future<List<T>> parseRows(QueryExecutor executor, List<List> rows) =>
      _withRelations(executor, rows);

  /// The matching records, with their relations ([loadRelations]).
  @override
  Future<List<T>> get(QueryExecutor executor) async {
    var sql = compile({});
    _log.fine(() => 'sql = $sql');
    logValues(_log, substitutionValues);
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

  /// Deletes the rows that match [where] (at most [limit] of them, after
  /// [offset], in the order of [orderBy]), and returns them.
  ///
  /// The rows returned are those deleted: where a delete selects them first,
  /// it deletes the rows it selected.
  ///
  /// Throws a [StateError] for a [groupBy], which a delete cannot have, and
  /// where it cannot tell the rows it selected, as the query selects no id:
  /// for a [limit] or an [offset] on MySQL or MariaDB, or on PostgreSQL with
  /// a join or a relation, and for a join that can leave a row out.
  Future<List<T>> delete(QueryExecutor executor) async {
    if (_groupBy != null) {
      throw StateError('A delete cannot have a GROUP BY.');
    }
    var whereClause =
        where?.compile(tableName: _isJoined ? tableName : null) ?? '';
    var conditions = whereClause.isEmpty ? '' : ' WHERE $whereClause';
    var limits = _limits;

    // One statement, of which RETURNING gives exactly the rows deleted.
    if (executor.dialect is PostgreSQLDialect &&
        !_isJoined &&
        !loadsRelations) {
      // PostgreSQL has no DELETE ... LIMIT: the rows are picked by ctid, and
      // the table of each, as a ctid is unique only within a partition.
      var rows = limits.isEmpty
          ? conditions
          : ' WHERE (tableoid, ctid) IN (${_selectOf(['tableoid', 'ctid'])})';
      var sql =
          'WITH $_written as (DELETE FROM $tableName$rows '
          'RETURNING $_returning) $_writtenRows';
      _log.fine(() => "Delete Query = $sql");
      logValues(_log, substitutionValues);
      var deleted = await executor.query(tableName, sql, substitutionValues);
      return deserializeList(deleted);
    }

    // The rows are selected first, in a transaction, as MySQL has no RETURNING
    // and relations may be deleted with them. A limit or a join decides which
    // rows those are, as the conditions alone do not: they are deleted by id.
    var byId = limits.isNotEmpty || _isJoined;
    if (byId && !fields.contains('id')) {
      if (limits.isNotEmpty || _leavesRowsOut) {
        throw StateError(
          'A delete of a query that does not select an id cannot have a '
          'LIMIT, an OFFSET or a join that leaves rows out, as it could not '
          'tell which rows it selected.',
        );
      }
      // A LEFT JOIN leaves no row out: the conditions decide.
      byId = false;
    }

    return executor.transaction((tx) async {
      // TODO: Can this be done with just *one* query?
      // Locked, so that another connection cannot select them too, and return
      // the rows that this one deleted.
      var rows = await tx.query(
        tableName,
        _compile(
          {},
          existing: byId ? '$tableName.id' : null,
          lock: executor.dialect is! PostgreSQLDialect
              ? ' FOR UPDATE'
              // PostgreSQL cannot lock the side of a join that may be `NULL`.
              : _addsRows
              ? ''
              : ' FOR UPDATE OF $tableName',
        ),
        substitutionValues,
      );
      var existing = await _withRelations(tx, rows);
      if (byId) {
        await _deleteByIds(tx, rows.map((row) => valueOf('id', row)));
      } else {
        // The conditions may name a join, which only PostgreSQL can pick by.
        var rows = executor.dialect is PostgreSQLDialect && _isJoined
            ? ' WHERE (tableoid, ctid) IN (${_selectOf(['tableoid', 'ctid'])})'
            : conditions;
        var sql = 'DELETE FROM $tableName$rows';
        _log.fine(() => "Delete Query = $sql");
        logValues(_log, substitutionValues);
        await tx.query(tableName, sql, substitutionValues);
      }
      return existing;
    });
  }

  /// Deletes the rows of [ids], in parts, as a database binds a limited number
  /// of parameters. A join may give the id of a row more than once.
  Future<void> _deleteByIds(
    QueryExecutor executor,
    Iterable<Object?> ids,
  ) async {
    for (var (list, values) in _idLists(ids)) {
      var sql = 'DELETE FROM $tableName WHERE id IN ($list)';
      _log.fine(() => "Delete Query = $sql");
      logValues(_log, values);
      await executor.query(tableName, sql, values);
    }
  }

  /// [ids], without repeats, as `IN` lists of the values they bind, in parts,
  /// as a database binds a limited number of parameters: an int as it is, and
  /// any other, such as a UUID, as a value.
  Iterable<(String, Map<String, dynamic>)> _idLists(
    Iterable<Object?> ids,
  ) sync* {
    var distinct = ids.where((id) => id != null).toSet().toList();
    for (var start = 0; start < distinct.length; start += _keysPerQuery) {
      var values = <String, dynamic>{};
      var list = <String>[];
      for (var id in distinct.skip(start).take(_keysPerQuery)) {
        if (id is int) {
          list.add('$id');
        } else {
          var name = 'id_key${values.length}';
          values[name] = id;
          list.add('@$name');
        }
      }
      yield (list.join(', '), values);
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
    _log.fine(() => "Insert Query = $sql");
    logValues(_log, substitutionValues);
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

  /// The substitution values of an insert: not those of the conditions of this
  /// query, which it ignores, and PostgreSQL's driver rejects as unused.
  Map<String, dynamic> get _valuesOfInsert {
    var conditions = where?.boundParameterNames.toSet() ?? const <String>{};
    return {
      for (var MapEntry(:key, :value) in substitutionValues.entries)
        if (!conditions.contains(key)) key: value,
    };
  }

  Future<Optional<T>> insert(QueryExecutor executor) {
    if (_groupBy != null) {
      throw StateError('An insert cannot have a GROUP BY.');
    }
    var insertion = values?.compileInsert(this, tableName);

    if (insertion == '') {
      throw StateError('No values have been specified for insertion.');
    } else {
      var returningSql = '';
      var sql = '$insertion';
      if (executor.dialect is PostgreSQLDialect) {
        // The row inserted, as RETURNING gives it: not filtered by any
        // conditions set on the query, which are not those of an insert.
        sql =
            'WITH $_written as ($insertion RETURNING $_returning) '
            '$_writtenRows';
      } else if (executor.dialect is MySQLDialect) {
        // Default to using 'id' as primary key in model
        if (fields.contains("id")) {
          // The row of the id given, by its parameter, as the database
          // gives no insert id of a key it does not generate, such as a
          // UUID; or else of the id the database gave it, of the placeholder
          // [insertIdParameter] that the executor binds to its insert id, not
          // the last row by id, which may be of another connection's insert.
          var idName = values?.toMap()['id'] == null
              ? null
              : values?.parameterNameOf(this, 'id');
          returningSql = _compile(
            {},
            rowsWhere: '$tableName.id=@${idName ?? insertIdParameter}',
            written: true,
          );
        } else {
          return _insertWithoutId(executor, sql);
        }
      } else {
        throw ArgumentError("Unsupported database dialect.");
      }

      _log.fine(() => "Insert Query = $sql");
      logValues(_log, substitutionValues);

      return executor
          .query(
            tableName,
            sql,
            _valuesOfInsert,
            returningQuery: returningSql,
            // Not on PostgreSQL, whose insert has its RETURNING already.
            returningFields: executor.dialect is PostgreSQLDialect
                ? const []
                : fields,
          )
          .then(
            (result) =>
                _first(_withRelations(executor, result.take(1).toList())),
          );
    }
  }

  /// Updates the rows that match [where] (at most [limit] of them, after
  /// [offset]) with [values], and returns them as updated.
  ///
  /// A join that can leave a row out, unlike a `LEFT JOIN`, decides which rows
  /// are updated, as it does which are selected.
  ///
  /// Each row updated is returned, whatever its new values join: with the
  /// columns of a join that no longer matches as `NULL`.
  ///
  /// Throws a [StateError] for a [limit], an [offset] or such a join on MySQL
  /// or MariaDB of a query that selects no id, as it could not tell the rows
  /// it selected.
  Future<List<T>> update(QueryExecutor executor) async {
    if (_groupBy != null) {
      throw StateError('An update cannot have a GROUP BY.');
    }
    var valuesClause = values?.compileForUpdate(this);
    if (valuesClause == null || valuesClause == '') {
      throw StateError('No values have been specified for update.');
    }
    var whereClause = where?.compile() ?? '';
    var conditions = whereClause.isEmpty ? '' : ' WHERE $whereClause';
    var limits = _limits;
    // A limit or a join decide which rows are updated, as in a select of this
    // query: not the conditions alone, which may name a join.
    var picks = limits.isNotEmpty || _isJoined;

    if (executor.dialect is PostgreSQLDialect) {
      // PostgreSQL has no UPDATE ... LIMIT: the rows are picked by ctid, and
      // the table of each, as a ctid is unique only within a partition.
      var rows = !picks
          ? conditions
          : ' WHERE (tableoid, ctid) IN (${_selectOf(['tableoid', 'ctid'])})';
      // The updated rows, as RETURNING gives them: not filtered by the
      // conditions again, which their new values may no longer match.
      var sql =
          'WITH $_written as (UPDATE $tableName $valuesClause$rows '
          'RETURNING $_returning) $_writtenRows';
      _log.fine(() => "Update Query = $sql");
      logValues(_log, substitutionValues);
      return _withRelations(
        executor,
        await executor.query(tableName, sql, substitutionValues),
      );
    }

    if (executor.dialect is! MySQLDialect) {
      throw ArgumentError("Unsupported database dialect.");
    }

    if (!fields.contains('id')) {
      // Nothing tells the rows it selected, so that a separate UPDATE ... LIMIT
      // could update other rows than those it returned, and MySQL has no
      // UPDATE ... OFFSET.
      if (limits.isNotEmpty || _leavesRowsOut) {
        throw StateError(
          'An update of a query that does not select an id cannot have a '
          'LIMIT, an OFFSET or a join that leaves rows out on this database, '
          'as it could not tell which rows it selected.',
        );
      }
      // Without a primary key, the rows that match are selected first, in a
      // transaction, and returned with the values they are updated to, as
      // their new values may no longer match the conditions.
      var select = compile({});
      var sql = 'UPDATE $tableName $valuesClause$conditions';
      _log.fine(() => "Update Query = $sql");
      logValues(_log, substitutionValues);
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
    // exactly those, by id. In a transaction, and locked, so that another
    // connection can neither pick them too, as of a queue, nor change them
    // before they are updated.
    return executor.transaction((tx) async {
      var select = picks
          ? _selectOf(['id'])
          : 'SELECT id FROM $tableName$conditions';
      var found = await tx.query(
        tableName,
        '$select FOR UPDATE',
        substitutionValues,
      );
      var rows = <List>[];
      for (var (list, ids) in _idLists(found.map((row) => row.first))) {
        var sql = 'UPDATE $tableName $valuesClause WHERE id IN ($list)';
        _log.fine(() => "Update Query = $sql");
        logValues(_log, substitutionValues);
        var values = {...substitutionValues, ...ids};
        await tx.query(tableName, sql, values);
        rows.addAll(
          await tx.query(
            tableName,
            _compile(
              {},
              rowsWhere: '${adornWithTableName('id')} IN ($list)',
              written: true,
            ),
            values,
          ),
        );
      }
      return _withRelations(tx, rows);
    });
  }

  Future<Optional<T>> _first(Future<List<T>> records) => records.then(
    (it) => it.isEmpty ? Optional.empty() : Optional.of(it.first),
  );

  Future<Optional<T>> updateOne(QueryExecutor executor) {
    return update(executor).then(
      (it) => it.isEmpty ? Optional.empty() : Optional.ofNullable(it.first),
    );
  }
}
