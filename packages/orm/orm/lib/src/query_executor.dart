import 'dart:async';

import '../angel3_orm.dart';

/// The name of the placeholder, `@angel3_insert_id`, that the `returningQuery`
/// of an insert on MySQL or MariaDB has for the id the database gave the row
/// inserted, as of an `AUTO_INCREMENT` column, which the executor binds to the
/// insert id of its driver.
const String insertIdParameter = 'angel3_insert_id';

/// An abstract interface that performs queries.
///
/// This class should be implemented.
abstract class QueryExecutor {
  const QueryExecutor();

  Dialect get dialect;

  /// Executes a single query, [query], which is complete: an insert, update
  /// or delete of `angel3_orm` on PostgreSQL has its `RETURNING` in a `WITH`
  /// clause, so an executor must not add one.
  ///
  /// [returningQuery] is the query of the row an insert on MySQL or MariaDB
  /// inserted, run after it, and [returningFields] its fields. Neither is
  /// given for PostgreSQL (since 10.0.2).
  Future<List<List>> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  });

  /// Enters a database transaction, performing the actions within,
  /// and returning the results of [f].
  ///
  /// If [f] fails, the transaction will be rolled back, and the
  /// responsible exception will be re-thrown.
  ///
  /// Whether nested transactions are supported depends on the
  /// underlying driver.
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f);
}
