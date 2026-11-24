/// The kind of a [QueryError].
enum QueryErrorKind {
  /// A value of a unique column or a primary key that a row has already.
  uniqueViolation,

  /// No value, or `NULL`, of a column that requires one.
  notNullViolation,

  /// A value of a foreign key that refers to no row, or the delete of a row
  /// that rows refer to.
  foreignKeyViolation,

  /// A value a column cannot hold, as a malformed UUID or text too long.
  invalidValue,
}

/// An error of the database that a query failed with, of a kind that does not
/// depend on the database, as the executor of a database classifies it
/// ([QueryExecutor.classifyError]).
///
/// It does not hold the values of the row, which the error of the database
/// may, as `Key (email)=(alice@example.com) already exists`, so that it can be
/// shown to a client.
final class QueryError {
  /// The kind of the error.
  final QueryErrorKind kind;

  /// The column of the error, if the database names it.
  final String? column;

  /// The constraint of the error, as the name of a unique index, if the
  /// database names it.
  final String? constraint;

  const QueryError(this.kind, {this.column, this.constraint});

  @override
  bool operator ==(Object other) =>
      other is QueryError &&
      other.kind == kind &&
      other.column == column &&
      other.constraint == constraint;

  @override
  int get hashCode => Object.hash(kind, column, constraint);

  @override
  String toString() => [
    'QueryError(${kind.name}',
    if (column != null) ', column: $column',
    if (constraint != null) ', constraint: $constraint',
    ')',
  ].join();
}
