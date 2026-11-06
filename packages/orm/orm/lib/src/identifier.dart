/// A part of a name: plain, or quoted, as a reserved word must be. A quoted
/// part has no quote of its own kind, so it cannot end early, and no backslash,
/// which MySQL takes as escaping the closing quote of a `"`.
const _part =
    r'(?:[A-Za-z_$][A-Za-z0-9_$]*|"[^"\\\x00-\x1f]+"|`[^`\\\x00-\x1f]+`)';

final RegExp _identifier = RegExp('^$_part(?:\\.$_part)*\$');

/// Returns [value], which is written into SQL as is, if it is a name, which
/// may be quoted (`"order"`) and qualified (`table.column`).
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
