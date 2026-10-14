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

  /// A `numeric(precision, scale)` column.
  ///
  /// Throws an [ArgumentError] if [precision] is not positive, or [scale] is
  /// negative or greater than [precision].
  MigrationColumn numeric(
    String name, {
    int precision = Column.defaultPrecision,
    int scale = Column.defaultScale,
  }) {
    return declareColumn(
      name,
      MigrationColumn(ColumnType.numeric, precision: precision, scale: scale),
    );
  }

  /// A `decimal(precision, scale)` column.
  ///
  /// Throws an [ArgumentError] if [precision] is not positive, or [scale] is
  /// negative or greater than [precision].
  MigrationColumn decimal(
    String name, {
    int precision = Column.defaultPrecision,
    int scale = Column.defaultScale,
  }) {
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

abstract class MutableTable extends Table implements MutableIndexes {
  void rename(String newName);

  void dropColumn(String name);

  void renameColumn(String name, String newName);

  /// Changes the type of the column [name] to [type], with the [length],
  /// [precision] and [scale] of a [Column] that does not give them.
  ///
  /// Throws an [ArgumentError] if [type] has a precision and [precision] is
  /// not positive, or has a scale and [scale] is negative or greater than
  /// [precision].
  void changeColumnType(
    String name,
    ColumnType type, {
    int length = Column.defaultLength,
    int precision = Column.defaultPrecision,
    int scale = Column.defaultScale,
  });

  void dropNotNull(String name);

  void setNotNull(String name);
}

abstract class MutableIndexes {
  void addIndex(String name, List<String> columns, IndexType type);

  void dropIndex(String name);

  void dropPrimaryIndex();
}
