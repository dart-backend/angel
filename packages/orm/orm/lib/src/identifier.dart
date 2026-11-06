/// A part of a name: plain, or quoted, as a reserved word must be.
///
/// A quoted part has only letters, digits, `_` and `$`, as whether a quote is
/// one depends on the database, which is not known here: a backtick is an
/// operator on PostgreSQL, so that what it encloses would be read as SQL.
const _part = r'(?:[A-Za-z_$][A-Za-z0-9_$]*|"[A-Za-z0-9_$]+"|`[A-Za-z0-9_$]+`)';

final RegExp _identifier = RegExp('^$_part(?:\\.$_part)*\$');
final RegExp _name = RegExp('^$_part\$');
final RegExp _plainName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Returns [value], which is written into SQL as is, if it is a name, which
/// may be quoted (`"order"`) and qualified (`table.column`).
///
/// Use the quote of the database: on MySQL and MariaDB, by default, `"order"`
/// is a string, so sorting or grouping by it does nothing, without an error.
///
/// Throws an [ArgumentError] for [argument] otherwise, so that a value from a
/// request cannot add SQL to a query. [description] says what it names.
String checkIdentifier(String value, String argument, String description) {
  if (!_identifier.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argument,
      'is not a valid $description identifier',
    );
  }
  return value;
}

/// Like [checkIdentifier], for a name of one part, to which the SQL adds its
/// table (`table.name`): it is not qualified.
String checkName(String value, String argument, String description) {
  if (!_name.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argument,
      'is not a valid $description name, of one part',
    );
  }
  return value;
}

/// Like [checkIdentifier], for a name that also makes another, such as a
/// parameter (`@name`) or a column of a subquery (`a0_name`): it is neither
/// quoted nor qualified, and has only letters, digits and `_`.
String checkPlainName(String value, String argument, String description) {
  if (!_plainName.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argument,
      'is not a plain $description name, of letters, digits and _',
    );
  }
  return value;
}
