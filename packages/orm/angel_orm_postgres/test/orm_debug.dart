import 'package:logging/logging.dart';

import 'belongs_to_test.dart';
import 'common.dart';

void main() async {
  hierarchicalLoggingEnabled = true;
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(print);
  //Logger.root.onRecord.listen((rec) {
  //  print(rec);
  //  if (rec.error != null) print(rec.error);
  //  if (rec.stackTrace != null) print(rec.stackTrace);
  //});

  belongsToTests(pg(['author', 'book']), close: closePg);
}
