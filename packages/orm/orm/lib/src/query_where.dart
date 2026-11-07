import 'builder.dart';
import 'union.dart';

/// Builds a SQL `WHERE` clause.
abstract class QueryWhere {
  final Set<QueryWhere> _and = {};
  final Set<QueryWhere> _not = {};
  final Set<QueryWhere> _or = {};
  final Set<String> _raw = {};

  Iterable<SqlExpressionBuilder> get expressionBuilders;

  void and(QueryWhere other) {
    _and.add(other);
  }

  void not(QueryWhere other) {
    _not.add(other);
  }

  void or(QueryWhere other) {
    _or.add(other);
  }

  /// Adds [whereRaw] to the conditions, as SQL, as it is: it must not hold
  /// values from a request. Bind them as substitution values of the query.
  ///
  /// In a [Union] on PostgreSQL, write a string that ends in a backslash as an
  /// escape string (`E'a\\'`): see [Union].
  void raw(String whereRaw) {
    _raw.add(whereRaw);
  }

  /// The conditions, joined with `AND`, followed by those of [or] clauses
  /// joined with `OR`; empty when there are none.
  String compile({String? tableName}) {
    var conditions = <String>[];

    for (var builder in expressionBuilders) {
      if (!builder.hasValue) continue;
      var key = builder.columnName;
      if (tableName != null) key = '$tableName.$key';
      var predicate = builder.compileFor(key);
      if (predicate != null) conditions.add(predicate);
    }

    for (var raw in _raw) {
      conditions.add('($raw)');
    }

    for (var other in _and) {
      var sql = other.compile(tableName: tableName);
      if (sql.isNotEmpty) conditions.add('($sql)');
    }

    for (var other in _not) {
      var sql = other.compile(tableName: tableName);
      if (sql.isNotEmpty) conditions.add('NOT ($sql)');
    }

    var result = conditions.join(' AND ');
    for (var other in _or) {
      var sql = other.compile(tableName: tableName);
      if (sql.isEmpty) continue;
      result = result.isEmpty ? '($sql)' : '$result OR ($sql)';
    }
    return result;
  }
}
