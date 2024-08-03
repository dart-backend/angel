import 'table.dart';

abstract class Schema {
  void drop(String tableName, {bool cascade = false});

  void dropAll(Iterable<String> tableNames, {bool cascade = false}) {
    for (var n in tableNames) {
      drop(n, cascade: cascade);
    }
  }

  void create(String tableName, void Function(Table table) callback);

  void createIfNotExists(String tableName, void Function(Table table) callback);

  void alter(String tableName, void Function(MutableTable table) callback);

  void indexes(
    String tableName,
    void Function(MutableIndexes indexes) callback,
  );
}
