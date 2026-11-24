import 'package:angel3_orm/angel3_orm.dart';
import 'package:sqlite3/common.dart' show SqliteException;

/// The [QueryError] of [error], a [SqliteException], by its extended result
/// code: `2067` (`SQLITE_CONSTRAINT_UNIQUE`), `1555`
/// (`SQLITE_CONSTRAINT_PRIMARYKEY`) and `2579` (`SQLITE_CONSTRAINT_ROWID`) a
/// duplicate key, `1299` (`SQLITE_CONSTRAINT_NOTNULL`) a `NULL` of a column
/// that requires a value, `787` (`SQLITE_CONSTRAINT_FOREIGNKEY`) a foreign
/// key, and `275` (`SQLITE_CONSTRAINT_CHECK`), `3091`
/// (`SQLITE_CONSTRAINT_DATATYPE`, of a `STRICT` table), `20`
/// (`SQLITE_MISMATCH`) and `18` (`SQLITE_TOOBIG`, a text or blob too long) an
/// invalid value. `null` of another error.
///
/// The column is that of the message, as `email` of `UNIQUE constraint
/// failed: users.email`, of a duplicate key of one column, a `NULL` and a
/// value of the wrong type in a `STRICT` table; a duplicate key of several
/// columns, or of the hidden `rowid`, names none. The constraint of a unique
/// index on an expression is the name of the index.
///
/// SQLite gives names in its messages as they are, unquoted, so the
/// executors record the table of the statement that failed, by which a
/// column is read from the message when the name of the table has a dot, or
/// that of a column `, `: the table as it is given, or without a schema
/// before its first dot, as `aux` of `aux.users`, in any case. A message of
/// another table, as when the table given is `''`, and an error of another
/// executor, are read up to the first dot. Of a `CHECK`, whose message is its
/// name, or its expression if it has none, the executors read the names of
/// the `CHECK`s of the table, in `temp`, `main` or an attached schema, and
/// the constraint is the name of the one that failed; it is `null` of an
/// error of another executor.
QueryError? classifySqliteError(Object error) {
  if (error is! SqliteException) return null;
  var message = error.message;
  var source = _sources[error];
  switch (error.extendedResultCode) {
    case 2067 || 1555:
      return _ofKey(QueryErrorKind.uniqueViolation, message, source?.table);
    case 2579:
      return const QueryError(QueryErrorKind.uniqueViolation);
    case 1299:
      return _ofKey(QueryErrorKind.notNullViolation, message, source?.table);
    case 787:
      return const QueryError(QueryErrorKind.foreignKeyViolation);
    case 275:
      var at = message.indexOf(_failed);
      var name = at < 0 ? null : message.substring(at + _failed.length);
      var known = source?.checks?.contains(name) ?? false;
      return QueryError(
        QueryErrorKind.invalidValue,
        constraint: known ? name : null,
      );
    case 3091:
      // `cannot store TEXT value in INTEGER column users.age`.
      var at = message.indexOf(_ofColumn);
      var column = at < 0
          ? null
          : _columnOf(message.substring(at + _ofColumn.length), source?.table);
      return QueryError(QueryErrorKind.invalidValue, column: column);
    case 20 || 18:
      return const QueryError(QueryErrorKind.invalidValue);
    default:
      return null;
  }
}

/// Records [table], that of the statement of [error], for
/// [classifySqliteError], and [checks], the names of its `CHECK`s, of
/// [checkNames].
void recordSqliteErrorSource(
  SqliteException error,
  String table, {
  Set<String>? checks,
}) => _sources[error] = (table: table, checks: checks);

/// Whether the executors read the names of the `CHECK`s of the table of
/// [error], for [recordSqliteErrorSource].
bool isCheckError(Object error) =>
    error is SqliteException && error.extendedResultCode == 275;

/// The SQL that selects the names of the schemas of a connection.
const String schemasQuery = 'SELECT name FROM pragma_database_list';

/// The SQL that selects the `CREATE TABLE` of a table of [schema], of the
/// name of its one parameter, in any case.
String tableSqlQuery(String schema) =>
    'SELECT sql FROM "${schema.replaceAll('"', '""')}".sqlite_schema '
    "WHERE type = 'table' AND name = ? COLLATE NOCASE";

/// The schemas and names that [table] may be, in the order that SQLite looks
/// for a table: [table] in each of [schemas], `temp` first, and then, if it
/// has a dot, its name after it in the schema before it, as `users` in `aux`
/// of `aux.users`.
List<(String, String)> tableCandidates(List<String> schemas, String table) {
  var ordered = [
    ...schemas.where((s) => s.toLowerCase() == 'temp'),
    ...schemas.where((s) => s.toLowerCase() != 'temp'),
  ];
  var dot = table.indexOf('.');
  var qualifier = dot < 0 ? null : table.substring(0, dot).toLowerCase();
  return [
    for (var schema in ordered) (schema, table),
    if (qualifier != null)
      for (var schema in ordered)
        if (schema.toLowerCase() == qualifier)
          (schema, table.substring(dot + 1)),
  ];
}

/// The names of the `CHECK`s of [createTable], the SQL of a table, as SQLite
/// writes them in its messages: unquoted.
Set<String> checkNames(String? createTable) => {
  if (createTable != null)
    for (var match in _namedCheck.allMatches(createTable))
      _unquote(match.group(1)!),
};

final Expando<({String table, Set<String>? checks})> _sources = Expando(
  'The sources of SQLite errors',
);

/// The error of a key, as `UNIQUE constraint failed: users.email`, of
/// [table], or `UNIQUE constraint failed: index 'idx_lower_email'`.
QueryError _ofKey(QueryErrorKind kind, String message, String? table) {
  var at = message.indexOf(_failed);
  if (at < 0) return QueryError(kind);
  var rest = message.substring(at + _failed.length);
  var index = _index.firstMatch(rest);
  if (index != null) return QueryError(kind, constraint: index.group(1));
  var prefix = _prefixOf(rest, table);
  var columns = prefix != null
      ? rest.substring(prefix.length).split(', $prefix')
      : rest.split(', ');
  if (columns.length != 1) return QueryError(kind);
  return QueryError(
    kind,
    column: prefix != null ? columns.single : _columnOf(rest, null),
  );
}

/// The column of [name], `table.column`: after the name of [table], if it is
/// that of the message, or else after the first dot.
String? _columnOf(String name, String? table) {
  var prefix = _prefixOf(name, table);
  if (prefix != null) return name.substring(prefix.length);
  var dot = name.indexOf('.');
  return dot < 0 ? null : name.substring(dot + 1);
}

/// The `table.` that [name] begins with, as it is written in it, of [table]
/// as it is given or without a schema before its first dot, in any case; or
/// `null`.
String? _prefixOf(String name, String? table) {
  if (table == null || table.isEmpty) return null;
  var dot = table.indexOf('.');
  for (var candidate in [table, if (dot >= 0) table.substring(dot + 1)]) {
    var prefix = '$candidate.';
    if (candidate.isNotEmpty &&
        name.length > prefix.length &&
        name.substring(0, prefix.length).toLowerCase() ==
            prefix.toLowerCase()) {
      return name.substring(0, prefix.length);
    }
  }
  return null;
}

String _unquote(String name) => switch (name[0]) {
  '"' ||
  '`' ||
  "'" => name.substring(1, name.length - 1).replaceAll(name[0] * 2, name[0]),
  '[' => name.substring(1, name.length - 1),
  _ => name,
};

const String _failed = 'constraint failed: ';

const String _ofColumn = ' column ';

final RegExp _index = RegExp(r"^index '(.+)'$");

// `CONSTRAINT positive_price CHECK`, of a column or of the table, its name
// quoted in any of the ways of SQLite, or not.
final RegExp _namedCheck = RegExp(
  r'''\bCONSTRAINT\s+("(?:[^"]|"")+"|`(?:[^`]|``)+`|'(?:[^']|'')+'|\[[^\]]+\]|[^\s(]+)\s+CHECK\b''',
  caseSensitive: false,
);
