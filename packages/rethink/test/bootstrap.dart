import 'dart:io';
import 'package:rethinkdb_dart/rethinkdb_dart.dart';

main() async {
  var r = new Rethinkdb();
  r.connect().then((conn) {
    r.tableCreate('todos').run(conn);
    print('Done');
    exit(0);
  });
}
