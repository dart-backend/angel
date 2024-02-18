import 'dart:io';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';

void main() async {
  var executor = PostgreSqlPoolExecutor(Pool.withEndpoints([
    Endpoint(
      host: Platform.environment['POSTGRES_HOSTNAME'] ?? 'localhost',
      port: 5432,
      database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123',
    )
  ],
      settings: PoolSettings(
          maxConnectionAge: Duration(hours: 1), maxConnectionCount: 5)));

  var rows = await executor.query('users', 'SELECT * FROM users', {});
  print(rows);
}
