import 'dart:io';
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';

void main() async {
  var r = RethinkDb();
  await r.connect().then((conn) {
    r.tableCreate('todos').run(conn);
    print('Done');
    exit(0);
  });
}
