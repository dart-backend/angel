import 'dart:io';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';

void main() async {
  var executor = PostgreSqlExecutorPool(Platform.numberOfProcessors, () {
    return PostgreSQLConnection('localhost', 5432, 'orm_test',
        username: 'test', password: 'test123');
  });

  var rows = await executor.query('users', 'SELECT * FROM users', {});
  print(rows);
}
