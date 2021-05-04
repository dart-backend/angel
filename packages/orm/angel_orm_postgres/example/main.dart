import 'dart:io';
import 'package:angel_orm_postgres/angel_orm_postgres.dart';
import 'package:postgres/postgres.dart';

main() async {
  var executor = PostgreSqlExecutorPool(Platform.numberOfProcessors, () {
    return PostgreSQLConnection('localhost', 5432, 'orm_test',
        username: 'test', password: 'test123');
  });

  var rows = await executor.query('users', 'SELECT * FROM users', {});
  print(rows);
}
