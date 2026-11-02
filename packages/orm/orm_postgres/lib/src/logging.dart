import 'package:angel3_orm/angel3_orm.dart' show debugMode;
import 'package:postgres/postgres.dart';

/// [error], as it may be logged: as it is in [debugMode]; else, a
/// [ServerException] without its detail and hint, which may hold the values
/// of a row, as `Key (email)=(alice@example.com) already exists`, nor the
/// quoted text of its message, but with its code, message and the names of
/// what it concerns.
Object loggableError(Object error) {
  if (debugMode || error is! ServerException) return error;
  return [
    // A value the server rejected, as of `invalid input syntax for type uuid:
    // "alice@example.com"`, is quoted in the message: quoted text is left
    // out, and the names are given apart.
    '${error.severity} ${error.code}: '
        '${error.message.replaceAll(RegExp(r'"[^"]*"'), '"…"')}',
    if (error.schemaName != null) 'schema: ${error.schemaName}',
    if (error.tableName != null) 'table: ${error.tableName}',
    if (error.columnName != null) 'column: ${error.columnName}',
    if (error.constraintName != null) 'constraint: ${error.constraintName}',
  ].join(' ');
}
