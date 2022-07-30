import 'dart:io';

import 'package:postgres/postgres.dart';

void main() async {
  /*
   * Granting permission in postgres
   * grant all privileges on database orm_test to test;
   * grant all privileges on sequence users_id_seq to test;
   */
  print("=== Start 'postgres' driver test");
  await testPgDriver().catchError((error, stackTrace) {
    print(error);
  });
  print("=== End test");
  print(" ");

  exit(0);
}

Future<void> testPgDriver() async {
  var conn = PostgreSQLConnection('localhost', 5432, 'orm_test',
      username: 'test', password: 'test123');
  await conn.open();

  print(">Test Select All");
  var result = await conn.query("SELECT * from users");
  print("Total records: ${result.length}");
  for (var row in result) {
    print(row[0]);
    for (var element in row) {
      print(element);
    }
  }

  print(">Test Insert");
  var params = {
    "username": "test",
    "password": "test123",
    "email": "test@demo.com",
    "updatedAt": DateTime.parse("1970-01-01 00:00:00")
  };

  result = await conn.query(
      "INSERT INTO users (username, password, email, updated_at) VALUES (@username, @password, @email, @updatedAt)",
      substitutionValues: params);
  //print("Last inserted ID: ${result.}");

  //print(">Test Select By ID");
  //result = await conn.query("SELECT * from users where id=@id",
  //    substitutionValues: {"id": result});
  //print("Read record: ${result.length}");
}
