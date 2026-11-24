import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';

/// The [QueryError] of [error], a [ServerException] of PostgreSQL, by its
/// SQLSTATE `code`: `23505` a unique violation, `23502` a `NOT NULL` one,
/// `23503` a foreign key one, and those of class `22`, data exceptions, as
/// `22P02` of a malformed UUID, an invalid value. `null` of another error.
QueryError? classifyPostgresError(Object error) {
  if (error is! ServerException) return null;
  var code = error.code ?? '';
  var kind = switch (code) {
    '23505' => QueryErrorKind.uniqueViolation,
    '23502' => QueryErrorKind.notNullViolation,
    '23503' => QueryErrorKind.foreignKeyViolation,
    _ when code.startsWith('22') => QueryErrorKind.invalidValue,
    _ => null,
  };
  if (kind == null) return null;
  return QueryError(
    kind,
    column: error.columnName,
    constraint: error.constraintName,
  );
}
