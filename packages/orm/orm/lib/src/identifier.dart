final RegExp _identifier = RegExp(
  r'^[A-Za-z_$][A-Za-z0-9_$]*(\.[A-Za-z_$][A-Za-z0-9_$]*)*$',
);

/// Returns [value], which is written into SQL as is, if it is a plain name,
/// which may be qualified (`table.column`).
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
