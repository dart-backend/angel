import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/custom_expr.dart';

void main() {
  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;
  late Number numberModel;

  setUp(() async {
    Logger.root.level = Level.INFO; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      print('${record.loggerName}: ${record.time}: ${record.message}');
    });

    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [NumberMigration(), AlphabetMigration()]);

    var now = DateTime.now();
    var nQuery = NumberQuery();
    nQuery.values
      ..createdAt = now
      ..updatedAt = now;
    var numbersModelOpt = await nQuery.insert(executor);
    numbersModelOpt.ifPresent((v) {
      numberModel = v;
    });
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) {
      await conn.close();
    }
  });

  test('fetches correct result', () async {
    expect(numberModel.two, 2);
  });

  test('in relation', () async {
    var abcQuery = AlphabetQuery();
    abcQuery.values
      ..value = 'abc'
      ..numbersId = numberModel.idAsInt
      ..createdAt = numberModel.createdAt
      ..updatedAt = numberModel.updatedAt;
    var abcOpt = await (abcQuery.insert(executor));
    expect(abcOpt.isPresent, true);
    abcOpt.ifPresent((abc) {
      expect(abc.numbers, numberModel);
      expect(abc.numbers?.two, 2);
      expect(abc.value, 'abc');
    });
  });
}
