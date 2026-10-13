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
      ),
    );
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
        if (c != '') {
          var additional = j.additionalFields.map(j.nameFor).toList();
          f.addAll(additional);
        } else {
          // If compilation failed, fill in NULL placeholders.
          for (var i = 0; i < j.additionalFields.length; i++) {
            f.add('NULL');
          }
        }
      }
    }
    if (withFields) {
      b.write(f.join(', '));
    }
    fromQuery ??= tableName;
    b.write(' FROM $fromQuery');

    // No joins if it's not a select.
    if (preamble == null) {
      if (_crossJoin != null) b.write(' CROSS JOIN $_crossJoin');
      for (var join in _joins) {
        var c = compiledJoins[join];
        if (c != null) b.write(' $c');
      }
    }

    var whereClause =
        rowsWhere ??
        where?.compile(tableName: includeTableName ? tableName : null);
    if (whereClause?.isNotEmpty == true) {
      b.write(' WHERE $whereClause');
    }
    if (_groupBy != null) b.write(' GROUP BY $_groupBy');
    var orderByClause = _orderBy.map((order) => order.compile()).join(', ');
    if (orderByClause.isNotEmpty) {
      b.write(' ORDER BY $orderByClause');
    }
    if (rowsWhere == null) {
      if (_limit != null) b.write(' LIMIT $_limit');
      if (_offset != null) b.write(' OFFSET $_offset');
    }
    return b.toString();
  }

  @override
  Future<Optional<T>> getOne(QueryExecutor executor) {
    //limit(1);
    return super.getOne(executor);
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

    if (_joins.isEmpty) {
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

          var hasPrimaryField = values?.hasField('id') ?? false;
          if (hasPrimaryField) {
            returningSql = '$selectSQL where $tableName.id=?';
          } else {
            returningSql = '$selectSQL order by $tableName.id desc limit 1';
          }
        } else {
          var returningSelect = values?.compileInsertSelect(this, tableName);
          var selectSQL = compile({});
          returningSql = '$selectSQL where $returningSelect';
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
          .then((result) {
            //_log.fine("Result Values: $result");
            return result.isEmpty
                ? Optional.empty()
                : deserialize(result.first);
          });
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
      return deserializeList(
        await executor.query(tableName, sql, substitutionValues),
      );
    }

    if (executor.dialect is! MySQLDialect) {
      throw ArgumentError("Unsupported database dialect.");
    }

    if (!fields.contains('id')) {
      // Without a primary key, the updated rows are selected again by the
      // conditions, which their new values may no longer match.
      var sql = 'UPDATE $tableName $valuesClause$conditions$limits';
      _log.fine("Update Query = $sql");
      return deserializeList(
        await executor.query(
          tableName,
          sql,
          substitutionValues,
          returningQuery: compile({}),
        ),
      );
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
    return deserializeList(
      await executor.query(
        tableName,
        _compile({}, rowsWhere: '${adornWithTableName('id')} IN ($ids)'),
        substitutionValues,
      ),
    );
  }

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
