import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_dart/exception.dart' show MySQLServerException;

/// The [QueryError] of [error], a [MySQLServerException] of MySQL or MariaDB,
/// by its error code: `1062` and `1586` a duplicate key, `1048` and `1364` a
/// `NULL`, or no value, of a column that requires one, `1216`, `1217`,
/// `1451` and `1452` a foreign key, and those of a value a column cannot
/// hold (`1264`, `1265`, `1292`, `1366`, `1406`, `3140`) an invalid value.
/// `null` of another error.
///
/// The column or the key is that of the error's message, as `id` of
/// `Column 'id' cannot be null`; the value it may quote is left out.
QueryError? classifyMySqlError(Object error) {
  if (error is! MySQLServerException) return null;
  var kind = switch (error.errorCode) {
    1062 || 1586 => QueryErrorKind.uniqueViolation,
    1048 || 1364 => QueryErrorKind.notNullViolation,
    1216 || 1217 || 1451 || 1452 => QueryErrorKind.foreignKeyViolation,
    1264 || 1265 || 1292 || 1366 || 1406 || 3140 => QueryErrorKind.invalidValue,
    _ => null,
  };
  if (kind == null) return null;
  var message = error.message;
  String? quoted(RegExp pattern) => pattern.firstMatch(message)?.group(1);
  return QueryError(
    kind,
    column: quoted(_column),
    constraint: kind == QueryErrorKind.uniqueViolation
        ? quoted(_key)
        : kind == QueryErrorKind.foreignKeyViolation
        ? quoted(_foreignKey)
        : null,
  );
}

// `Column 'id' cannot be null`, `Field 'id' doesn't have a default value`,
// `Data too long for column 'name'`, `... for column 'id' at row 1`.
final RegExp _column = RegExp(r"(?:[Cc]olumn|Field) [`']([^`']+)[`']");

// `Duplicate entry '…' for key 'users.PRIMARY'`.
final RegExp _key = RegExp(r"for key '([^']+)'$");

// `... CONSTRAINT `posts_ibfk_1` FOREIGN KEY ...`.
final RegExp _foreignKey = RegExp(r'CONSTRAINT `([^`]+)`');
