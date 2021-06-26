import 'dart:io';
import 'package:rethinkdb_dart/rethinkdb_dart.dart';

void main() async {
  var r = Rethinkdb();
  await r.connect().then((conn) {
    r.tableCreate('todos').run(conn);
    print('Done');
    exit(0);
  });
}
