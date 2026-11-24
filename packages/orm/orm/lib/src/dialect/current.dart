import 'dart:async';

import '../query_executor.dart';
import 'dialect.dart';

/// The zone value of the [Dialect] that a query is compiled for.
const Symbol _dialectKey = #angel3_orm.dialect;

/// The dialect that SQL is being compiled for: that of the executor of the
/// query being run ([inDialectOf]), or PostgreSQL's, of a query compiled
/// without an executor, as `query.compile({})` is.
///
/// It is a zone value, as a query compiles its conditions after awaiting, as
/// in a transaction, and its joins and relations compile queries of their
/// own, which a value of each query would not reach.
Dialect get currentDialect =>
    Zone.current[_dialectKey] as Dialect? ?? const PostgreSQLDialect();

/// Runs [body], whose SQL is compiled for the dialect of [executor].
R inDialectOf<R>(QueryExecutor executor, R Function() body) {
  var dialect = executor.dialect;
  if (identical(Zone.current[_dialectKey], dialect)) return body();
  return runZoned(body, zoneValues: {_dialectKey: dialect});
}
