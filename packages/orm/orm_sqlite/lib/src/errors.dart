import 'package:angel3_orm/angel3_orm.dart';
import 'package:sqlite3/common.dart' show SqliteException;

/// The [QueryError] of [error], a [SqliteException], by its extended result
/// code: `2067` (`SQLITE_CONSTRAINT_UNIQUE`) and `1555`
/// (`SQLITE_CONSTRAINT_PRIMARYKEY`) a duplicate key, `1299`
/// (`SQLITE_CONSTRAINT_NOTNULL`) a `NULL` of a column that requires a value,
/// `787` (`SQLITE_CONSTRAINT_FOREIGNKEY`) a foreign key, and `275`
/// (`SQLITE_CONSTRAINT_CHECK`) and `20` (`SQLITE_MISMATCH`) an invalid value.
/// `null` of another error.
///
/// The column is that of the message, as `email` of `UNIQUE constraint
/// failed: users.email`: the first of a key of several columns.
QueryError? classifySqliteError(Object error) {
  if (error is! SqliteException) return null;
  var kind = switch (error.extendedResultCode) {
    2067 || 1555 => QueryErrorKind.uniqueViolation,
    1299 => QueryErrorKind.notNullViolation,
    787 => QueryErrorKind.foreignKeyViolation,
    275 || 20 => QueryErrorKind.invalidValue,
    _ => null,
  };
  if (kind == null) return null;
  return QueryError(kind, column: _column.firstMatch(error.message)?.group(1));
}

// `UNIQUE constraint failed: users.email, users.name`.
final RegExp _column = RegExp(r'constraint failed: [^.\s,]+\.([^\s,]+)');
