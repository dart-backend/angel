import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';

import 'package:optional/optional.dart';

/// A SQL `SELECT` query builder.
abstract class Query<T, Where extends QueryWhere> extends QueryBase<T> {
  final _log = Logger('Query');

  final List<JoinBuilder> _joins = [];
  final Map<String, int> _names = {};
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
    // var n = _names[name] ??= 0;
    // _names[name]++;
    var n = 0;
    var nn = _names[name];
    if (nn != null) {
      n = nn;
      nn++;
      _names[name] = nn;
    } else {
      _names[name] = 0; //1;
    }
    return n == 0 ? name : '$name$n';
  }

  /// Makes a [Where] clause.
  Where newWhereClause() {
    throw UnsupportedError(
        'This instance does not support creating WHERE clauses.');
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

  String Function() _compileJoin(tableName, Set<String> trampoline) {
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
          tableName, 'tableName', 'must be a String or Query');
    }
  }

  void _makeJoin(
      tableName,
      Set<String>? trampoline,
      String? alias,
      JoinType type,
      String localKey,
      String foreignKey,
      String op,
      List<String> additionalFields) {
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
    _joins.add(JoinBuilder(type, this, to, localKey, foreignKey,
        op: op,
        alias: alias,
        additionalFields: additionalFields,
        aliasAllFields: tableName is Query));
  }

  /// Execute an `INNER JOIN` against another table.
  void join(tableName, String localKey, String foreignKey,
      {String op = '=',
      List<String> additionalFields = const [],
      Set<String>? trampoline,
      String? alias}) {
    _makeJoin(tableName, trampoline, alias, JoinType.inner, localKey,
        foreignKey, op, additionalFields);
  }

  /// Execute a `LEFT JOIN` against another table.
  void leftJoin(tableName, String localKey, String foreignKey,
      {String op = '=',
      List<String> additionalFields = const [],
      Set<String>? trampoline,
      String? alias}) {
    _makeJoin(tableName, trampoline, alias, JoinType.left, localKey, foreignKey,
        op, additionalFields);
  }

  /// Execute a `RIGHT JOIN` against another table.
  void rightJoin(tableName, String localKey, String foreignKey,
      {String op = '=',
      List<String> additionalFields = const [],
      Set<String>? trampoline,
      String? alias}) {
    _makeJoin(tableName, trampoline, alias, JoinType.right, localKey,
        foreignKey, op, additionalFields);
  }

  /// Execute a `FULL OUTER JOIN` against another table.
  void fullOuterJoin(tableName, String localKey, String foreignKey,
      {String op = '=',
      List<String> additionalFields = const [],
      Set<String>? trampoline,
      String? alias}) {
    _makeJoin(tableName, trampoline, alias, JoinType.full, localKey, foreignKey,
        op, additionalFields);
  }

  /// Execute a `SELF JOIN`.
  void selfJoin(tableName, String localKey, String foreignKey,
      {String op = '=',
      List<String> additionalFields = const [],
      Set<String>? trampoline,
      String? alias}) {
    _makeJoin(tableName, trampoline, alias, JoinType.self, localKey, foreignKey,
        op, additionalFields);
  }

  @override
  String compile(Set<String> trampoline,
      {bool includeTableName = false,
      String? preamble,
      bool withFields = true,
      String? fromQuery}) {
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
      f = List<String>.from(fields.map((s) {
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
      }));
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
    if (withFields) b.write(f.join(', '));
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
        where?.compile(tableName: includeTableName ? tableName : null);
    if (whereClause?.isNotEmpty == true) {
      b.write(' WHERE $whereClause');
    }
    if (_groupBy != null) b.write(' GROUP BY $_groupBy');
    var orderByClause = _orderBy.map((order) => order.compile()).join(', ');
    if (orderByClause.isNotEmpty) {
      b.write(' ORDER BY $orderByClause');
    }
    if (_limit != null) b.write(' LIMIT $_limit');
    if (_offset != null) b.write(' OFFSET $_offset');
    return b.toString();
  }

  @override
  Future<Optional<T>> getOne(QueryExecutor executor) {
    //limit(1);
    return super.getOne(executor);
  }

  Future<List<T>> delete(QueryExecutor executor) {
    var sql = compile({}, preamble: 'DELETE', withFields: false);

    //_log.warning("Delete Query = $sql");

    if (_joins.isEmpty) {
      return executor
          .query(tableName, sql, substitutionValues,
              returningFields: fields.map(adornWithTableName).toList())
          .then((it) => deserializeList(it));
    } else {
      return executor.transaction((tx) async {
        // TODO: Can this be done with just *one* query?
        var existing = await get(tx);
        //var sql = compile(preamble: 'SELECT $tableName.id', withFields: false);
        return tx
            .query(tableName, sql, substitutionValues)
            .then((_) => existing);
      });
    }
  }

  Future<Optional<T>> deleteOne(QueryExecutor executor) {
    return delete(executor).then((it) =>
        it.isEmpty == true ? Optional.empty() : Optional.ofNullable(it.first));
  }

  Future<Optional<T>> insert(QueryExecutor executor) {
    var insertion = values?.compileInsert(this, tableName);

    if (insertion == '') {
      throw StateError('No values have been specified for insertion.');
    } else {
      var sql = compile({});
      var returningSql = '';
      if (executor.dialect is PostgreSQLDialect) {
        var returning = fields.map(adornWithTableName).join(', ');
        sql = 'WITH $tableName as ($insertion RETURNING $returning) $sql';
      } else if (executor.dialect is MySQLDialect) {
        // Default to using 'id' as primary key in model
        if (fields.contains("id")) {
          returningSql = '$sql where $tableName.id=?';
        } else {
          var returningSelect = values?.compileInsertSelect(this, tableName);
          returningSql = '$sql where $returningSelect';
        }

        sql = '$insertion';
      } else {
        throw ArgumentError("Unsupported database dialect.");
      }

      //_log.warning("Insert Query = $sql");

      return executor
          .query(tableName, sql, substitutionValues,
              returningQuery: returningSql)
          .then((result) {
        // Return SQL execution results
        //if (result.isNotEmpty) {
        //  for (var element in result.first) {
        //    _log.fine("value: $element");
        //  }
        //}
        return result.isEmpty ? Optional.empty() : deserialize(result.first);
      });
    }
  }

  Future<List<T>> update(QueryExecutor executor) async {
    var updateSql = StringBuffer('UPDATE $tableName ');
    var valuesClause = values?.compileForUpdate(this);

    if (valuesClause == '') {
      throw StateError('No values have been specified for update.');
    }
    updateSql.write(' $valuesClause');
    var whereClause = where?.compile();
    if (whereClause?.isNotEmpty == true) {
      updateSql.write(' WHERE $whereClause');
    }
    if (_limit != null) updateSql.write(' LIMIT $_limit');

    var returning = fields.map(adornWithTableName).join(', ');
    var sql = compile({});
    var returningSql = '';
    if (executor.dialect is PostgreSQLDialect) {
      sql = 'WITH $tableName as ($updateSql RETURNING $returning) $sql';
    } else if (executor.dialect is MySQLDialect) {
      returningSql = sql;
      sql = '$updateSql';
    } else {
      throw ArgumentError("Unsupported database dialect.");
    }
    //_log.fine("Update Query = $sql");

    return executor
        .query(tableName, sql, substitutionValues, returningQuery: returningSql)
        .then((it) => deserializeList(it));
  }

  Future<Optional<T>> updateOne(QueryExecutor executor) {
    return update(executor).then(
        (it) => it.isEmpty ? Optional.empty() : Optional.ofNullable(it.first));
  }
}
