import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:mysql1/mysql1.dart';
import 'package:logging/logging.dart';
import 'package:optional/optional.dart';
part 'main.g.dart';

void main() async {
  //hierarchicalLoggingEnabled = true;

  await mariaDBExample();
  //await mysqlExample();

  exit(0);
}

Future<void> mariaDBExample() async {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(print);

  var settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      db: 'orm_test',
      user: 'test',
      password: 'test123');
  var connection = await MySqlConnection.connect(settings);

  print("Connected to MariaDb");
  var logger = Logger('orm_mysql');
  var executor = MariaDbExecutor(connection, logger: logger);

  var query = TodoQuery();
  query.values
    ..text = 'Clean your room!'
    ..updatedAt = DateTime.now().toUtc()
    ..isComplete = false;

  var todo = await query.insert(executor);
  print(todo.value.toJson());

  var query2 = TodoQuery()..where!.id.equals(todo.value.idAsInt);
  var todo2 = await query2.getOne(executor);
  print(todo2.value.toJson());
  print(todo == todo2);
}

Future<void> mysqlExample() async {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(print);

  var connection = await MySQLConnection.createConnection(
      host: "localhost",
      port: 3306,
      databaseName: "orm_test",
      userName: "test",
      password: "test123",
      secure: false);

  print("Connected to MySQL");
  var logger = Logger('orm_mysql');
  await connection.connect(timeoutMs: 10000);
  var executor = MySqlExecutor(connection, logger: logger);

  var query = TodoQuery();
  query.values
    ..text = 'Clean your room!'
    ..updatedAt = DateTime.now().toUtc()
    ..isComplete = false;

  var todo = await query.insert(executor);
  print(todo.value.toJson());

  var query2 = TodoQuery()..where!.id.equals(todo.value.idAsInt);
  var todo2 = await query2.getOne(executor);
  print(todo2.value.toJson());
  print(todo == todo2);
}

@serializable
@orm
abstract class _Todo extends Model {
  String? get text;

  @DefaultsTo(false)
  bool? isComplete;
}
