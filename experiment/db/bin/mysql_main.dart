import 'dart:io';

import 'package:mysql_client/mysql_client.dart';
import 'package:mysql1/mysql1.dart';

void main() async {
  print("=== Start 'mysql1' driver test");
  await testMySQL1Driver().catchError((error, stackTrace) {
    print(error);
  });
  print("=== End test");
  print(" ");

  print("=== Start 'mysql_client' driver test");
  await testMySQLClientDriver().catchError((error, stackTrace) {
    print(error);
  });
  print("=== End test");
  print(" ");

  //sleep(Duration(seconds: 5));
  exit(0);
}

Future<void> testMySQLClientDriver() async {
  var connection = await MySQLConnection.createConnection(
      host: "localhost",
      port: 3306,
      databaseName: "orm_test",
      userName: "test",
      password: "test123",
      secure: false);
  await connection.connect(timeoutMs: 30000);

  print(">Test Select All");
  var result = await connection.execute("SELECT * from users");
  print("Total records: ${result.rows.length}");

  print(">Test Insert");
  var params = {
    "username": "test",
    "password": "test123",
    "email": "test@demo.com",
    "updatedAt": DateTime.parse("1970-01-01 00:00:00")
  };

  result = await connection.execute(
      "INSERT INTO users (username, password, email, updated_at) VALUES (:username, :password, :email, :updatedAt)",
      params);
  print("Last inserted ID: ${result.lastInsertID}");

  print(">Test Select By ID");
  result = await connection.execute(
      "SELECT * from users where id=:id", {"id": result.lastInsertID.toInt()});
  print("Read record: ${result.rows.first.assoc()}");
}

Future<void> testMySQL1Driver() async {
  var settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      db: 'orm_test',
      user: 'test',
      password: 'test123',
      timeout: Duration(seconds: 60));
  var connection = await MySqlConnection.connect(settings);

  print(">Test Select All");
  var result = await connection.query("SELECT * from users");
  print("Total records: ${result.length}");

  print(">Test Insert");
  var params = [
    "test",
    "test123",
    "test@demo.com",
    DateTime.parse("1970-01-01 00:00:00").toUtc()
  ];

  // DateTime.parse("1970-01-01 00:00:01").toUtc()
  result = await connection.query(
      "INSERT INTO users (username, password, email, updated_at) VALUES (?, ?, ?, ?)",
      params);
  print("Last inserted ID: ${result.insertId}");

  print(">Test Select By ID");
  result = await connection
      .query("SELECT * from users where id=?", [result.insertId]);
  print("Read record: ${result.first.values}");

  var d = DateTime.parse("1970-01-01 00:00:00").toUtc();
  print("Local time: ${d.toLocal()}");
}
