import 'dart:async';
import 'dart:io';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';

Future<Connection> dbConnection() async {
  return Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'angel_orm_service_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'postgres',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'password',
    ),
  );
}

Future<PostgreSqlExecutor> connect() async {
  final conn = await dbConnection();

  var executor = PostgreSqlExecutor(conn);
  return executor;
}
