import 'dart:async';

import 'package:logging/logging.dart';

import 'query_executor.dart';
import 'union.dart';
import 'package:optional/optional.dart';

/// A base class for objects that compile to SQL queries, typically within an ORM.
abstract class QueryBase<T> {
  final _log = Logger('QueryBase');

  /// Casts to perform when querying the database.
  Map<String, String> get casts => {};

  /// `AS` aliases to inject into the query, if any.
  Map<String, String> aliases = {};

  /// Values to insert into a prepared statement.
  final Map<String, dynamic> substitutionValues = {};

  /// The table against which to execute this query.
  String get tableName;

  /// The list of fields returned by this query.
  ///
  /// @deprecated If it's `null`, then this query will perform a `SELECT *`.
  /// If it's empty, then this query will perform a `SELECT *`.
  List<String> get fields;

  /// A String of all [fields], joined by a comma (`,`).
  String get fieldSet => fields
      .map((k) {
        var cast = casts[k];
        if (!aliases.containsKey(k)) {
          return cast == null ? k : 'CAST ($k AS $cast)';
        } else {
          var inner = cast == null ? k : '(CAST ($k AS $cast))';
          return '$inner AS ${aliases[k]}';
        }
      })
      .join(', ');

  String compile(
    Set<String> trampoline, {
    bool includeTableName = false,
    String preamble = '',
    bool withFields = true,
  });

  Optional<T> deserialize(List row);

  List<T> deserializeList(List<List<dynamic>> it) {
    var optResult = it.map(deserialize).toList();
    var result = <T>[];
    for (var element in optResult) {
      element.ifPresent((item) {
        result.add(item);
      });
    }

    return result;
  }

  Future<List<T>> get(QueryExecutor executor) async {
    var sql = compile({});

    _log.fine('sql = $sql');
    _log.fine('values = $substitutionValues');

    return executor.query(tableName, sql, substitutionValues).then((it) {
      return deserializeList(it);
    });
  }

  Future<Optional<T>> getOne(QueryExecutor executor) {
    //return get(executor).then((it) => it.isEmpty ?  : it.first);
    return get(executor).then(
      (it) => it.isEmpty ? Optional.empty() : Optional.ofNullable(it.first),
    );
  }

  Union<T> union(QueryBase<T> other) {
    return Union(this, other);
  }

  Union<T> unionAll(QueryBase<T> other) {
    return Union(this, other, all: true);
  }
}
