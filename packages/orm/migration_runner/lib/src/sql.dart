import 'package:angel3_orm/angel3_orm.dart';

/// The SQL of the default [value] of a column: [RawSql] as it is, a [String]
/// as a string literal, and other values as their [Object.toString].
///
/// A string literal is in single quotes, each of which is doubled, which every
/// database reads as a quote. MySQL and MariaDB also read a backslash as an
/// escape, unless `NO_BACKSLASH_ESCAPES` is set, so with [escapeBackslashes]
/// each backslash is doubled too. PostgreSQL reads a backslash as itself.
String compileDefault(Object value, {required bool escapeBackslashes}) {
  if (value is RawSql) return value.value;
  if (value is! String) return value.toString();
  var literal = value.replaceAll("'", "''");
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
    '`${unquoteIdentifier(name, '`').replaceAll('`', '``')}`';

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

/// [name] as a PostgreSQL identifier, in double quotes, each of which is
/// doubled, so that it may be a reserved word or have capitals.
String quotePostgresIdentifier(String name) =>
    '"${name.replaceAll('"', '""')}"';

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
