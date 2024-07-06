import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_rethinkdb/angel3_rethinkdb.dart';
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
import 'package:logging/logging.dart';

void main() async {
  RethinkDb r = RethinkDb();
  var conn = await r.connect(
      db: 'testDB',
      host: "localhost",
      port: 28015,
      user: "admin",
      password: "");

  Angel app = Angel();
  app.use('/todos', RethinkService(conn, r.table('todos')));

  app.errorHandler = (e, req, res) async {
    print('Whoops: $e');
  };

  app.logger = Logger.detached('angel')..onRecord.listen(print);
}
