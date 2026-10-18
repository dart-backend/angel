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
