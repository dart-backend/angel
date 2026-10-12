import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';

import 'common.dart';

/// Creates the `testDB` database and its `todos` table, if missing.
void main() async {
  var r = RethinkDb();
  var conn = await r.connect(
    host: rethinkHost,
    port: 28015,
    user: "admin",
    password: "",
  );
  try {
    var dbs = await r.dbList().run(conn) as List;
    if (!dbs.contains('testDB')) await r.dbCreate('testDB').run(conn);

    var tables = await r.db('testDB').tableList().run(conn) as List;
    if (!tables.contains('todos')) {
      await r.db('testDB').tableCreate('todos').run(conn);
    }
    print('Done');
  } finally {
    conn.close();
  }
}
