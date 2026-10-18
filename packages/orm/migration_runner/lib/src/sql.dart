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

/// [name] as a MySQL or MariaDB identifier, in backticks, each of which is
/// doubled, so that it may be a reserved word such as `order`.
String quoteMySqlIdentifier(String name) => '`${name.replaceAll('`', '``')}`';

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
