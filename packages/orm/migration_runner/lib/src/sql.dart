import 'package:angel3_orm/angel3_orm.dart';

/// The SQL of the default [value] of a column: [RawSql] as it is, a number or
/// a [bool] as its [Object.toString], a [DateTime] as a string literal of its
/// date and time, such as `'2020-01-02 03:04:05.000'`, and other values, such
/// as a [String], as a string literal of their [Object.toString].
///
/// A [DateTime] is of its own time zone. With [utcOffset], as PostgreSQL
/// takes, a UTC one is given as such (`'2020-01-02 03:04:05.000+00'`), so
/// that a `timestamp with time zone` is not read in the time zone of the
/// session. MySQL and MariaDB take no offset, so a UTC one is of the time
/// zone of their session.
///
/// A string literal is in single quotes, each of which is doubled, which every
/// database reads as a quote. MySQL and MariaDB also read a backslash as an
/// escape, unless `NO_BACKSLASH_ESCAPES` is set, so with [escapeBackslashes]
/// each backslash is doubled too. PostgreSQL reads a backslash as itself.
///
/// A `double` that is not finite is a string literal, `'NaN'`, `'Infinity'`
/// or `'-Infinity'`, with [nonFinite], as PostgreSQL takes, and throws an
/// [ArgumentError] otherwise, as MySQL and MariaDB have no such values.
String compileDefault(
  Object value, {
  required bool escapeBackslashes,
  bool utcOffset = false,
  bool nonFinite = false,
}) {
  if (value is RawSql) return value.value;
  if (value is double && !value.isFinite) {
    if (!nonFinite) {
      throw ArgumentError.value(
        value,
        null,
        'Not a value that MySQL or MariaDB have, which have no NaN or '
        'infinity',
      );
    }
    return value.isNaN
        ? "'NaN'"
        : value.isNegative
        ? "'-Infinity'"
        : "'Infinity'";
  }
  if (value is num || value is bool) return value.toString();
  if (value is DateTime) {
    // Without the `T` and `Z` of ISO 8601, which MariaDB does not take.
    var utc = value.isUtc && utcOffset;
    value =
        '${value.toIso8601String().replaceFirst('T', ' ').replaceFirst(RegExp(r'Z$'), '')}'
        '${utc ? '+00' : ''}';
  }
  var literal = value.toString().replaceAll("'", "''");
  if (escapeBackslashes) literal = literal.replaceAll(r'\', r'\\');
  return "'$literal'";
}

/// The integer type of each serial type, which is not a type a column can be
/// changed to on PostgreSQL, nor one MySQL and MariaDB have.
const Map<ColumnType, ColumnType> serialIntegers = {
  ColumnType.smallSerial: ColumnType.smallInt,
  ColumnType.serial: ColumnType.int,
  ColumnType.bigSerial: ColumnType.bigInt,
};

/// [name] as a MySQL or MariaDB identifier, in backticks, each of which is
/// doubled, so that it may be a reserved word such as `order`. A name already
/// in backticks, such as `` `order` ``, is quoted once.
String quoteMySqlIdentifier(String name) =>
    quoteMySqlPart(unquoteIdentifier(name, '`'));

/// [part], a name without its backticks, in backticks, each of which is
/// doubled; it is not unquoted again.
String quoteMySqlPart(String part) => '`${part.replaceAll('`', '``')}`';

/// [name] without the [quotes] around it, of which each doubled one in it is
/// one, as `` `a``b` `` is `` a`b ``. A name not in one of them is as it is.
String unquoteIdentifier(String name, [String quotes = '`"']) {
  name = name.trim();
  if (name.length < 2) return name;
  var quote = name[0];
  if (quotes.contains(quote) && name.endsWith(quote)) {
    return name.substring(1, name.length - 1).replaceAll('$quote$quote', quote);
  }
  return name;
}

/// The parts of the qualified [name], such as `` `shop`.`orders` ``, split at
/// each `.` that is not in [quotes], and each unquoted as [unquoteIdentifier],
/// so that `` `my.table` `` is one part.
List<String> splitQualifiedName(String name, [String quotes = '`"']) {
  var parts = <String>[];
  var start = 0;
  String? quote;
  for (var i = 0; i < name.length; i++) {
    var c = name[i];
    if (quote != null) {
      // A doubled quote is one in the name.
      if (c == quote) {
        if (i + 1 < name.length && name[i + 1] == quote) {
          i++;
        } else {
          quote = null;
        }
      }
    } else if (quotes.contains(c)) {
      quote = c;
    } else if (c == '.') {
      parts.add(unquoteIdentifier(name.substring(start, i), quotes));
      start = i + 1;
    }
  }
  parts.add(unquoteIdentifier(name.substring(start), quotes));
  return parts;
}

/// The table [name], which may be qualified by its database, such as
/// `shop.orders`, as a MySQL or MariaDB identifier, each part in backticks
/// (`` `shop`.`orders` ``). A part may be given in backticks or in double
/// quotes, as earlier versions took it.
String quoteMySqlTableName(String name) =>
    splitQualifiedName(name).map(quoteMySqlPart).join('.');

/// The [column] of an index as SQL: a name, which may be in quotes, quoted
/// by [quote], which takes it without its quotes, such as [quoteMySqlPart] or
/// [quotePostgresPart], and as it is otherwise, as it may be a prefix, such
/// as `body(100)`, an expression, such as `lower(email)`, or have an order,
/// such as `email DESC`.
String compileIndexColumn(String column, String Function(String) quote) {
  var name = column.trim();
  // A name in either quotes is unquoted once and quoted by [quote], as MySQL
  // reads one in double quotes as a string, and PostgreSQL has no backticks.
  if (_quotedName.hasMatch(name)) return quote(unquoteIdentifier(name));
  if (_plainName.hasMatch(name)) return quote(name);
  return column;
}

/// A name in backticks or double quotes, each of which is doubled in it.
final RegExp _quotedName = RegExp(r'^(`([^`]|``)*`|"([^"]|"")*")$');

/// A name without spaces, parentheses, quotes or other punctuation of SQL.
final RegExp _plainName = RegExp(r'''^[^\s()`"',;.]+$''');

/// [name] as a PostgreSQL identifier, in double quotes, each of which is
/// doubled, so that it may be a reserved word or have capitals. A name
/// already in double quotes, such as `"order"`, is quoted once.
String quotePostgresIdentifier(String name) =>
    quotePostgresPart(unquoteIdentifier(name, '"'));

/// [part], a name without its quotes, in double quotes, each of which is
/// doubled; it is not unquoted again, so that a name whose quotes are its own
/// keeps them.
String quotePostgresPart(String part) => '"${part.replaceAll('"', '""')}"';

/// The parts of the PostgreSQL table [name], which may be qualified by its
/// schema, such as `audit.events`, each without its double quotes.
List<String> postgresNameParts(String name) => splitQualifiedName(name, '"');

/// The table [name], which may be qualified by its schema, such as
/// `audit.events`, as a PostgreSQL identifier, each part in double quotes
/// (`"audit"."events"`).
String quotePostgresTableName(String name) =>
    postgresNameParts(name).map(quotePostgresPart).join('.');

/// The own name of the PostgreSQL table [name], without its schema and
/// quotes.
String unqualifiedPostgresName(String name) => postgresNameParts(name).last;

/// The PostgreSQL object [name], such as an index or a sequence, without its
/// quotes, in the schema of the table [table], if it is qualified by one,
/// quoted (`"audit"."events_id_seq"`).
String quotePostgresInSchemaOf(String table, String name) {
  var parts = postgresNameParts(table);
  return [
    ...parts.sublist(0, parts.length - 1),
    name,
  ].map(quotePostgresPart).join('.');
}

/// The table [table] renamed to [newName], which stays in the schema of
/// [table], as PostgreSQL keeps a table renamed in its schema.
///
/// [newName] may be qualified by that schema, as a `RENAME TO` does not move
/// a table to another schema, which `ALTER TABLE ... SET SCHEMA` does; another
/// throws an [ArgumentError]. If [table] is not qualified, its schema is not
/// known, and a qualified [newName] is taken to be of it.
String renamedPostgresTable(String table, String newName) {
  var parts = postgresNameParts(table);
  var newParts = postgresNameParts(newName);
  if (parts.length == 1) return quotePostgresTableName(newName);
  // Compared quoted, so that a part with a dot is not read as two.
  String schemaOf(List<String> parts) =>
      parts.sublist(0, parts.length - 1).map(quotePostgresPart).join('.');
  var schema = schemaOf(parts);
  if (newParts.length > 1 && schemaOf(newParts) != schema) {
    throw ArgumentError.value(
      newName,
      'newName',
      'A table is renamed in its schema, $schema; to move it to another, use '
          'SET SCHEMA',
    );
  }
  return quotePostgresInSchemaOf(table, newParts.last);
}

/// The statements of the MySQL or MariaDB [sql], without the `;` that ends
/// them, and without those that are empty.
///
/// A `;` in a string, a quoted identifier or a comment does not end a
/// statement. A string or identifier is in `'`, `"` or `` ` ``, in which the
/// quote is doubled or, but in an identifier, escaped with a backslash. A
/// comment is from `#` or `-- ` to the end of the line, or in `/* */`.
List<String> splitMySqlStatements(String sql) {
  var statements = <String>[];
  var start = 0;
  void end(int i) {
    var statement = sql.substring(start, i).trim();
    if (statement.isNotEmpty) statements.add(statement);
    start = i + 1;
  }

  for (var i = 0; i < sql.length; i++) {
    var c = sql[i];
    if (c == ';') {
      end(i);
    } else if (c == "'" || c == '"' || c == '`') {
      // To the closing quote, which a doubled quote is not.
      for (i++; i < sql.length; i++) {
        if (sql[i] == r'\' && c != '`') {
          i++;
        } else if (sql[i] == c) {
          if (i + 1 < sql.length && sql[i + 1] == c) {
            i++;
          } else {
            break;
          }
        }
      }
    } else if (c == '#' ||
        (sql.startsWith('--', i) &&
            (i + 2 == sql.length || sql[i + 2].trim().isEmpty))) {
      var newline = sql.indexOf('\n', i);
      i = newline < 0 ? sql.length : newline;
    } else if (sql.startsWith('/*', i)) {
      var close = sql.indexOf('*/', i + 2);
      i = close < 0 ? sql.length : close + 1;
    }
  }
  end(sql.length);
  return statements;
}
