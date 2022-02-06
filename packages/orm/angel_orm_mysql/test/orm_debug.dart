import 'package:angel3_orm_test/angel3_orm_test.dart';
import 'package:logging/logging.dart';

import 'common.dart';

void main() async {
  //hierarchicalLoggingEnabled = true;
  Logger.root
    ..level = Level.INFO
    ..onRecord.listen(print);
  //Logger.root.onRecord.listen((rec) {
  //  print(rec);
  //  if (rec.error != null) print(rec.error);
  //  if (rec.stackTrace != null) print(rec.stackTrace);
  //});

  belongsToTests(my(['author', 'book']), close: closeMy);

  //edgeCaseTests(my(['unorthodox', 'weird_join', 'song', 'numba']),
  //    close: closeMy);
}
