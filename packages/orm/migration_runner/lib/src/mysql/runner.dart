import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';

import '../mysql_family_runner.dart';
import 'schema.dart';

/// A MySQL database migration runner, of a connection of `mysql_dart`.
///
/// MySQL commits each change of a table on its own, so a migration is
/// recorded in the `migrations` table once it has run.
class MySqlMigrationRunner extends MySqlFamilyMigrationRunner<MySqlSchema> {
  MySqlMigrationRunner(
    MySQLConnection connection, {
    Iterable<Migration> migrations = const [],
    @Deprecated(
      'Not used: the runner uses the connection as it is given, and close() closes it.',
    )
    bool connected = false,
  }) : super(connection, Logger('MysqlMigrationRunner'), migrations);

  @override
  MySqlSchema newSchema() => MySqlSchema();
}
