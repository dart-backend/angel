import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';

void main() async {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });
  var logger = Logger('mysql');

  var connection = await MySQLConnection.createConnection(
    host: "localhost",
    port: 3306,
    databaseName: "orm_test",
    userName: "test",
    password: "Test123",
    secure: true,
  );

  await connection.connect(timeoutMs: 10000);
  logger.fine("Connected to MySQL");

  var result = await connection.execute(
    "SELECT id, created_at, updated_at, make, description, family_friendly, recalled_at, price FROM cars order by cars.id desc limit 1",
  );

  /*
  // Not working
  var result1 = await connection.execute(
      "SELECT roles.id, roles.created_at, roles.updated_at, roles.name, a0.id, a0.created_at, a0.updated_at, a0.username, a0.password, a0.email FROM roles  LEFT JOIN (SELECT role_users.role_id, users.id, users.created_at, users.updated_at, users.username, users.password, users.email FROM users LEFT JOIN role_users ON role_users.user_id=users.id) a0 ON roles.id=a0.role_id order by roles.id desc limit 1");

  // Not working
  var result2 = await connection.execute(
      "SELECT * FROM roles LEFT JOIN (SELECT role_users.role_id, users.id, users.created_at, users.updated_at, users.username, users.password, users.email FROM users LEFT JOIN role_users ON role_users.user_id=users.id) a0 ON roles.id=a0.role_id order by roles.id desc limit 1");

  // Working
  var result3 = await connection
      .execute("SELECT * FROM roles order by roles.id desc limit 1");

  var result4 = await connection.execute(
      "SELECT * FROM roles LEFT JOIN role_users ON role_users.role_id=roles.id LEFT JOIN users ON users.id=role_users.user_id order by roles.id desc limit 1");
  */

  //logger.fine(rowResult.assoc());
  //logger.fine(rowResult.typedAssoc());
  /*
  Map<String, dynamic> parseSQLNamedResult(IResultSet res) {
    var colNames = [];
    var columns = [];
    var prefix = "1__";
    for (var c in res.cols) {
      if (colNames.contains(c.name)) {
        // If collumn name is duplicated, add "1_" as prefix
        var tmpColName = "$prefix${c.name}";
        while (colNames.contains(tmpColName)) {
          tmpColName = "$prefix$tmpColName";
        }
        columns.add((name: tmpColName, type: c.type));
        colNames.add(tmpColName);
      } else {
        columns.add((name: c.name, type: c.type));
        colNames.add(c.name);
      }
    }

    logger.fine(colNames);

    var row = res.rows.first;

    Map<String, dynamic> retResult = {};
    for (var i = 0; i < row.numOfColumns; i++) {
      var val = row.typedColAt(i);
      var colName = columns[i].name;
      logger.fine("$colName $val");

      retResult[colName] = val;
    }

    return retResult;
  }
  */
  List<List<dynamic>> parseSQLResult(IResultSet res) {
    var colTypes = res.cols.map((col) => col.type).toList();

    var mappedResult = <List>[];
    for (var row in res.rows) {
      List<dynamic> retResult = [];
      for (var i = 0; i < row.numOfColumns; i++) {
        var val = row.typedColAt(i);
        /*
        switch (colTypes[i].convertStringValueToProvidedType(value)) {
          case int:
            decodedValue = int.parse(value);
            break;
          case double:
            decodedValue = double.parse(value);
            break;
          case num:
            decodedValue = num.parse(value);
            break;
          case bool:
            decodedValue = int.parse(value) > 0;
            break;
          case String:
            decodedValue = value;
            break;
          default:
            decodedValue = value;
            break;
        }
        */
        //colTypes[i].intVal = MySQLColumnType.
        var tmp = colTypes[i].convertStringValueToProvidedType(val);
        retResult.add(tmp);
      }
      mappedResult.add(retResult);
    }

    return mappedResult;
  }

  var sqlResult = parseSQLResult(result);
  logger.fine(sqlResult);

  if (connection.connected) {
    await connection.close();
  }
}
