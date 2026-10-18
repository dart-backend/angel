import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

import '../mysql_family.dart';
import 'table.dart';

/// A MariaDB database schema generator
class MariaDbSchema extends MySqlFamilySchema {
  final _log = Logger('MariaDbSchema');

  @override
  MariaDbTable newTable() => MariaDbTable();

  @override
  MariaDbAlterTable newAlterTable(String tableName) =>
      MariaDbAlterTable(tableName);

  @override
  MariaDbIndexes newIndexes(String tableName) => MariaDbIndexes(tableName);

  /// Runs the SQL of the schema in a transaction, and throws if it fails.
  ///
  /// The statements before an alter table that changes a column's type are
  /// run before the column's constraints are read, as they may create the
  /// table or rename the column.
  Future<int> run(MySqlConnection connection) async {
    var affectedRows = 0;
    await connection.transaction((TransactionContext ctx) async {
      await runWith(
        execute: (sql) async {
          Results? result = await ctx.query(sql).catchError((e) {
            _log.severe('Failed to run query: [ $sql ]', e);
            throw e;
          });
          affectedRows += result.affectedRows ?? 0;
        },
        // `mysql1` may give text as a `Blob`.
        query: (sql) async => [
          for (var row in await ctx.query(sql))
            [for (var value in row) value?.toString()],
        ],
      );
    });

    return affectedRows;
  }
}
