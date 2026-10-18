import 'package:angel3_orm/angel3_orm.dart';

import 'column.dart';

abstract class Table {
  MigrationColumn declareColumn(String name, Column column);

  MigrationColumn declare(String name, ColumnType type) =>
      declareColumn(name, MigrationColumn(type));

  MigrationColumn serial(String name) => declare(name, ColumnType.serial);

  MigrationColumn integer(String name) => declare(name, ColumnType.int);

  MigrationColumn float(String name) => declare(name, ColumnType.float);

  MigrationColumn double(String name) => declare(name, ColumnType.double);

  /// A `numeric(precision, scale)` column. Without a [precision] or [scale], it is
  /// an unbounded `numeric` on PostgreSQL, and `numeric(17, 3)` on MySQL and MariaDB
  /// ([Column.defaultPrecision] and [Column.defaultScale]).
  /// With a [precision] but no [scale], the scale is [Column.defaultScale], or
  /// the precision if smaller, e.g. `numeric(10, 3)`; give `scale: 0` for whole
  /// numbers.
  ///
  /// Throws an [ArgumentError] if [precision] is not positive, or [scale] is
  /// negative or greater than the precision.
  MigrationColumn numeric(String name, {int? precision, int? scale}) {
    return declareColumn(
      name,
      MigrationColumn(ColumnType.numeric, precision: precision, scale: scale),
    );
  }

  /// A `decimal(precision, scale)` column. Without a [precision] or [scale], it is
  /// an unbounded `decimal` on PostgreSQL, and `decimal(17, 3)` on MySQL and MariaDB
  /// ([Column.defaultPrecision] and [Column.defaultScale]).
  /// With a [precision] but no [scale], the scale is [Column.defaultScale], or
  /// the precision if smaller, e.g. `decimal(10, 3)`; give `scale: 0` for whole
  /// numbers.
  ///
  /// Throws an [ArgumentError] if [precision] is not positive, or [scale] is
  /// negative or greater than the precision.
  MigrationColumn decimal(String name, {int? precision, int? scale}) {
    return declareColumn(
      name,
      MigrationColumn(ColumnType.decimal, precision: precision, scale: scale),
    );
  }

  MigrationColumn boolean(String name) => declare(name, ColumnType.boolean);

  MigrationColumn date(String name) => declare(name, ColumnType.date);

  //@deprecated
  //MigrationColumn dateTime(String name) => timeStamp(name, timezone: true);

  MigrationColumn timeStamp(String name, {bool timezone = false}) {
    if (!timezone) {
      return declare(name, ColumnType.timeStamp);
    }
    return declare(name, ColumnType.timeStampWithTimeZone);
  }

  MigrationColumn text(String name) => declare(name, ColumnType.text);

  MigrationColumn varChar(String name, {int? length}) {
    if (length == null) return declare(name, ColumnType.varChar);
    return declareColumn(
      name,
      MigrationColumn(ColumnType.varChar, length: length),
    );
  }
}

/// The `defaultValue` of [MutableTable.changeColumnType] that removes the
/// default of the column, where `null` keeps it.
const Object noDefault = _NoDefault();

final class _NoDefault {
  const _NoDefault();

  @override
  String toString() => 'noDefault';
}

abstract class MutableTable extends Table implements MutableIndexes {
  void rename(String newName);

  void dropColumn(String name);

  void renameColumn(String name, String newName);

  /// Changes the type of the column [name] to [type], with its [length],
  /// [precision] and [scale], which are as for a [Column]: without a precision
  /// or scale, a `numeric` is unbounded on PostgreSQL, so that its values are
  /// kept, and `numeric(17, 3)` on MySQL and MariaDB.
  ///
  /// The column has the constraints given after the change: it is nullable or
  /// not as [isNullable], has the default [defaultValue], or none if it is
  /// [noDefault], and on MySQL and MariaDB is `AUTO_INCREMENT` or not as
  /// [autoIncrement]. Those not given (`null`) are kept as they are; a default
  /// that the new type cannot have, such as `'n/a'` of an `int`, is removed
  /// with [noDefault]. MySQL and MariaDB define the whole column
  /// again, so the migration runner reads them from the database first; they
  /// keep its `NOT NULL`, `DEFAULT`, `AUTO_INCREMENT` and `ON UPDATE`, but not
  /// others, such as its `COMMENT` or `COLLATE`.
  ///
  /// On PostgreSQL, [using] is the expression that converts the values when
  /// there is no implicit cast, such as `price::numeric` from `text`.
  ///
  /// Throws an [ArgumentError] if [type] has a precision and [precision] is
  /// not positive, or has a scale and [scale] is negative or greater than the
  /// precision.
  void changeColumnType(
    String name,
    ColumnType type, {
    int length = Column.defaultLength,
    int? precision,
    int? scale,
    bool? isNullable,
    Object? defaultValue,
    bool? autoIncrement,
    String? using,
  });

  void dropNotNull(String name);

  void setNotNull(String name);
}

abstract class MutableIndexes {
  void addIndex(String name, List<String> columns, IndexType type);

  void dropIndex(String name);

  void dropPrimaryIndex();
}
