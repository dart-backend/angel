abstract class Dialect {
  bool get cteSupport;

  /// Whether a `WITH` may have an `INSERT`, an `UPDATE` or a `DELETE` with a
  /// `RETURNING`, of which a write returns its rows in one statement.
  ///
  /// Without it, an insert selects its row after it, by the id the database
  /// gave it, of `insertIdParameter`, and an update or a delete selects the
  /// rows it writes first, in a transaction.
  bool get writableCteSupport;

  /// Whether a `SELECT` may lock its rows with `FOR UPDATE`, as an update or
  /// a delete does with the rows it selects first, when it has no
  /// [writableCteSupport].
  bool get rowLockSupport;
}

class MySQLDialect implements Dialect {
  const MySQLDialect();

  @override
  bool get cteSupport => true;

  @override
  bool get writableCteSupport => false;

  @override
  bool get rowLockSupport => true;
}

class PostgreSQLDialect implements Dialect {
  const PostgreSQLDialect();

  @override
  bool get cteSupport => true;

  @override
  bool get writableCteSupport => true;

  @override
  bool get rowLockSupport => true;
}

/// SQLite 3.35 or later.
///
/// Queries are written for it as for MySQL, without `FOR UPDATE`, which SQLite
/// does not have, as a transaction that writes holds the whole database.
class SqliteDialect implements Dialect {
  const SqliteDialect();

  @override
  bool get cteSupport => true;

  @override
  bool get writableCteSupport => false;

  @override
  bool get rowLockSupport => false;

  /// [dateTime] as SQLite stores it: UTC text of a fixed width, such as
  /// `2024-03-10 12:34:56.000000Z`, which sorts and compares in time order,
  /// and which [DateTime.parse] reads as UTC.
  ///
  /// `angel3_orm_sqlite` stores a [DateTime] so, and `angel3_migration_runner`
  /// gives a default so.
  ///
  /// Throws an [ArgumentError] for a year before 0 or after 9999, whose text
  /// would not sort in time order.
  static String formatDateTime(DateTime dateTime) {
    var dt = dateTime.toUtc();
    if (dt.year < 0 || dt.year > 9999) {
      throw ArgumentError.value(
        dateTime,
        'dateTime',
        'SQLite stores a date of a year from 0 to 9999',
      );
    }
    String pad(int n, int width) => n.toString().padLeft(width, '0');
    var micros = dt.millisecond * 1000 + dt.microsecond;
    return '${pad(dt.year, 4)}-${pad(dt.month, 2)}-${pad(dt.day, 2)} '
        '${pad(dt.hour, 2)}:${pad(dt.minute, 2)}:${pad(dt.second, 2)}'
        '.${pad(micros, 6)}Z';
  }
}
