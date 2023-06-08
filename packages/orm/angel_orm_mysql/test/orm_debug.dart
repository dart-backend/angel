import 'package:logging/logging.dart';

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

  //belongsToTests(createTables(['author', 'book']), close: dropTables);

  //hasOneTests(my(['leg', 'foot']), close: closeMy);
  //standaloneTests(my(['car']), close: closeMy);
}
