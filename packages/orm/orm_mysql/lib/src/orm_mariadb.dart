part of 'orm_mysql.dart';

/// A [MySqlExecutor] that stores a [DateTime] as UTC: a local one is sent as
/// UTC, and a date or time column is read back as UTC.
///
/// Of a connection of `mysql_dart`, as [MySqlExecutor]; it works with MySQL
/// as well as MariaDB.
class MariaDbExecutor extends MySqlExecutor {
  MariaDbExecutor(MySQLConnection connection, {Logger? logger})
    : super._(connection, logger ?? Logger('MariaDbExecutor'), utc: true);

  MariaDbExecutor._transaction(MySQLConnection connection, Logger logger)
    : super._transaction(connection, logger, true);

  @override
  MariaDbExecutor _newTransaction(MySQLConnection connection) =>
      MariaDbExecutor._transaction(connection, logger);
}
