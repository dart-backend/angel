import 'dart:io';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';

void main() async {
  var executor = PostgreSqlPoolExecutor(PgPool(
    PgEndpoint(
      host: 'localhost',
      port: 5432,
      database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123',
    ),
    settings: PgPoolSettings()
      ..maxConnectionAge = Duration(hours: 1)
      ..concurrency = 5,
  ));

  var rows = await executor.query('users', 'SELECT * FROM users', {});
  print(rows);
}
