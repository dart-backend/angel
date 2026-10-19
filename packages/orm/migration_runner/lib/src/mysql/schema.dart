import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';

import '../mysql_family.dart';
import '../sql.dart';
import 'table.dart';

/// A MySQL database schema generator
class MySqlSchema extends MySqlFamilySchema {
  final _log = Logger('MysqlSchema');

  @override
  MysqlTable newTable() => MysqlTable();

  @override
  MysqlAlterTable newAlterTable(String tableName) => MysqlAlterTable(tableName);

  @override
  MysqlIndexes newIndexes(String tableName) => MysqlIndexes(tableName);

  /// Runs the SQL of the schema in a transaction, and throws if it fails.
  ///
  /// The statements before an alter table that changes a column's type are
  /// run before the column's constraints are read, as they may create the
  /// table or rename the column.
  Future<int> run(MySQLConnection connection) async {
    var affectedRows = 0;
    await connection
        .transactional((ctx) async {
          await runWith(
            // `mysql_dart` reads the result of only the first statement of
            // a query, and then the others as those of the next queries, so
            // the statements are run one by one.
            execute: (sql) async {
              for (var statement in splitMySqlStatements(sql)) {
                //print('Query: $statement');
                var result = await ctx.execute(statement).catchError((e) {
                  _log.severe('Failed to run query: [ $statement ]', e);
                  throw Exception(e);
                });
                affectedRows += result.affectedRows.toInt();
              }
            },
            query: (sql) async {
              var result = await ctx.execute(sql);
              return [
                for (var row in result.rows)
                  [for (var i = 0; i < result.numOfColumns; i++) row.colAt(i)],
              ];
            },
          );
        })
        .catchError((e) {
          _log.severe('Failed to run query in a transaction', e);
          throw e;
        });

    return affectedRows;
  }
}
