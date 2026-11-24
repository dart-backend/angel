import 'package:angel3_orm/angel3_orm.dart';
import 'package:sqlite3/common.dart' show SqliteException;

/// The [QueryError] of [error], a [SqliteException], by its extended result
/// code: `2067` (`SQLITE_CONSTRAINT_UNIQUE`), `1555`
/// (`SQLITE_CONSTRAINT_PRIMARYKEY`) and `2579` (`SQLITE_CONSTRAINT_ROWID`) a
/// duplicate key, `1299` (`SQLITE_CONSTRAINT_NOTNULL`) a `NULL` of a column
/// that requires a value, `787` (`SQLITE_CONSTRAINT_FOREIGNKEY`) a foreign
/// key, and `275` (`SQLITE_CONSTRAINT_CHECK`), `3091`
/// (`SQLITE_CONSTRAINT_DATATYPE`, of a `STRICT` table) and `20`
/// (`SQLITE_MISMATCH`) an invalid value. `18` (`SQLITE_TOOBIG`) is an invalid
/// value of a statement that writes, as of a text or blob too long; of a
/// query that only reads, it is of the query, as of a result too long, and
/// `null`. `null` of another error.
///
/// The column is that of the message, as `email` of `UNIQUE constraint
/// failed: users.email`, of a duplicate key of one column, a `NULL` and a
/// value of the wrong type in a `STRICT` table; a duplicate key of several
/// columns, or of the hidden `rowid`, names none. The constraint of a unique
/// index on an expression is the name of the index.
///
/// SQLite gives names in its messages as they are, unquoted, so the
/// executors record the table of the query that failed, by which a column is
/// read from the message when the name of the table has a dot, or that of a
/// column `, `. The table is read as SQL reads it: `aux.users` is `users` of
/// the schema `aux`, `"my.t"` a table of that name, in any case of ASCII
/// letters, as SQLite compares names. A message of another table, as of a
/// trigger, names no column. A query given the table `''`, and an error of
/// another executor, are read up to the first dot.
///
/// Of a `CHECK`, whose message is its name, or its expression if it has none,
/// the executors read the names of the `CHECK`s of the table, of its schema,
/// or else of `temp`, `main` or an attached one, as SQLite looks for it, and
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
    case 20:
      return const QueryError(QueryErrorKind.invalidValue);
    case 18:
      var statement = source?.sql ?? error.causingStatement;
      return statement != null && writes(statement)
          ? const QueryError(QueryErrorKind.invalidValue)
          : null;
    default:
      return null;
  }
}

/// Records [table] and [sql], the table and the SQL of the query of [error],
/// for [classifySqliteError], and [checks], the names of the `CHECK`s of
/// [table], of [checkNames].
void recordSqliteErrorSource(
  SqliteException error,
  String table,
  String sql, {
  Set<String>? checks,
}) => _sources[error] = (table: table, sql: sql, checks: checks);

/// Whether the executors read the names of the `CHECK`s of the table of
/// [error], for [recordSqliteErrorSource].
bool isCheckError(Object error) =>
    error is SqliteException && error.extendedResultCode == 275;

/// Whether [sql] writes: an `INSERT`, an `UPDATE`, a `DELETE` or a `REPLACE`,
/// or a `WITH` of one.
bool writes(String sql) =>
    _writes.hasMatch(sql) ||
    (_with.hasMatch(sql) && _writesAfterWith.hasMatch(sql));

/// The SQL that selects the names of the schemas of a connection.
const String schemasQuery = 'SELECT name FROM pragma_database_list';

/// The SQL that selects the `CREATE TABLE` of a table of [schema], of the
/// name of its one parameter, in any case.
String tableSqlQuery(String schema) =>
    'SELECT sql FROM "${schema.replaceAll('"', '""')}".sqlite_schema '
    "WHERE type = 'table' AND name = ? COLLATE NOCASE";

/// The schemas and names that [table], as it is written in SQL, may be, in
/// the order that SQLite looks for it: in its schema, if it is qualified, as
/// `users` of `aux` of `aux.users`, or else in each of [schemas], `temp`
/// first. None if it is not a name.
List<(String, String)> tableCandidates(List<String> schemas, String table) {
  var parsed = _parseTable(table);
  if (parsed == null) return const [];
  var (schema, name) = parsed;
  if (schema != null) return [(schema, name)];
  bool isTemp(String s) => _asciiLower(s) == 'temp';
  return [
    for (var s in schemas.where(isTemp)) (s, name),
    for (var s in schemas.where((s) => !isTemp(s))) (s, name),
  ];
}

/// The names of the `CHECK`s of [createTable], the SQL of a table, as SQLite
/// writes them in its messages: unquoted.
Set<String> checkNames(String? createTable) => {
  if (createTable != null)
    for (var match in _namedCheck.allMatches(createTable))
      _unquote(match.group(1)!),
};

final Expando<({String table, String sql, Set<String>? checks})> _sources =
    Expando('The sources of SQLite errors');

/// The error of a key, as `UNIQUE constraint failed: users.email`, of
/// [table], or `UNIQUE constraint failed: index 'idx_lower_email'`.
QueryError _ofKey(QueryErrorKind kind, String message, String? table) {
  var at = message.indexOf(_failed);
  if (at < 0) return QueryError(kind);
  var rest = message.substring(at + _failed.length);
  var index = _index.firstMatch(rest);
  if (index != null) return QueryError(kind, constraint: index.group(1));
  if (table == null || table.isEmpty) {
    var columns = rest.split(', ');
    return QueryError(
      kind,
      column: columns.length == 1 ? _columnOf(rest, null) : null,
    );
  }
  var prefix = _prefixOf(rest, table);
  if (prefix == null) return QueryError(kind);
  var columns = rest.substring(prefix.length).split(', $prefix');
  return QueryError(kind, column: columns.length == 1 ? columns.single : null);
}

/// The column of [name], `table.column`: after the name of [table], or none
/// if it is of another table; or, if [table] is `null` or `''`, after the
/// first dot.
String? _columnOf(String name, String? table) {
  if (table == null || table.isEmpty) {
    var dot = name.indexOf('.');
    return dot < 0 ? null : name.substring(dot + 1);
  }
  var prefix = _prefixOf(name, table);
  return prefix == null ? null : name.substring(prefix.length);
}

/// The `table.` that [name] begins with, as it is written in it, of the name
/// of [table], as it is written in SQL, in any case of ASCII letters; or
/// `null`.
String? _prefixOf(String name, String table) {
  var parsed = _parseTable(table);
  if (parsed == null) return null;
  var prefix = '${parsed.$2}.';
  if (name.length <= prefix.length) return null;
  var start = name.substring(0, prefix.length);
  return _asciiLower(start) == _asciiLower(prefix) ? start : null;
}

/// The schema, if it has one, and the name of [table], a name of one or two
/// parts as SQL reads it, each plain or quoted; or `null`.
(String?, String)? _parseTable(String table) {
  var parts = [
    for (var match in _part.allMatches(table)) _unquote(match.group(1)!),
  ];
  // Each part, and the dot between two, is all of [table].
  if (parts.isEmpty || parts.length > 2) return null;
  if (_part.allMatches(table).map((m) => m.group(0)).join() != table) {
    return null;
  }
  return parts.length == 1 ? (null, parts[0]) : (parts[0], parts[1]);
}

/// [s] with its ASCII letters in lower case, as SQLite compares names.
String _asciiLower(String s) => String.fromCharCodes(
  s.codeUnits.map((c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c),
);

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

// A part of a name, quoted in any of the ways of SQLite, or plain, and the
// dot before it, but for the first.
final RegExp _part = RegExp(
  r'''(?:^|(?<=.)\.)("(?:[^"]|"")+"|`(?:[^`]|``)+`|\[[^\]]+\]|[^."`\[\]\s]+)''',
);

final RegExp _writes = RegExp(
  r'^\s*(?:INSERT|UPDATE|DELETE|REPLACE)\b',
  caseSensitive: false,
);

final RegExp _with = RegExp(r'^\s*WITH\b', caseSensitive: false);

final RegExp _writesAfterWith = RegExp(
  r'\)\s*(?:INSERT|UPDATE|DELETE|REPLACE)\b',
  caseSensitive: false,
);

// `CONSTRAINT positive_price CHECK`, of a column or of the table, its name
// quoted in any of the ways of SQLite, or not.
final RegExp _namedCheck = RegExp(
  r'''\bCONSTRAINT\s+("(?:[^"]|"")+"|`(?:[^`]|``)+`|'(?:[^']|'')+'|\[[^\]]+\]|[^\s(]+)\s+CHECK\b''',
  caseSensitive: false,
);
