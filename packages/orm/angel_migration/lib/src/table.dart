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

  MigrationColumn numeric(String name, {int precision = 17, int scale = 3}) {
    return declare(name, ColumnType.numeric);
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
      Column(type: ColumnType.varChar, length: length),
    );
  }
}

abstract class MutableTable extends Table implements MutableIndexes {
  void rename(String newName);

  void dropColumn(String name);

  void renameColumn(String name, String newName);

  void changeColumnType(String name, ColumnType type);

  void dropNotNull(String name);

  void setNotNull(String name);
}

abstract class MutableIndexes {
  void addIndex(String name, List<String> columns, IndexType type);

  void dropIndex(String name);

  void dropPrimaryIndex();
}
