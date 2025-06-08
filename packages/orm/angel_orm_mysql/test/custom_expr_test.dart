import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/custom_expr.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });

  late MySQLConnection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;
  late Number numbersModel;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [NumberMigration(), AlphabetMigration()]);

    var now = DateTime.now();
    var nQuery = NumberQuery();
    nQuery.values
      ..createdAt = now
      ..updatedAt = now;
    var numbersModelOpt = await nQuery.insert(executor);
    numbersModelOpt.ifPresent((v) {
      numbersModel = v;
    });
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.connected) {
      await conn.close();
    }
  });

  test('fetches correct result', () async {
    expect(numbersModel.two, 2);
  });

  test('in relation', () async {
    var abcQuery = AlphabetQuery();
    abcQuery.values
      ..value = 'abc'
      ..numbersId = numbersModel.idAsInt
      ..createdAt = numbersModel.createdAt
      ..updatedAt = numbersModel.updatedAt;
    var abcOpt = await (abcQuery.insert(executor));
    expect(abcOpt.isPresent, true);
    abcOpt.ifPresent((abc) {
      expect(abc.numbers, numbersModel);
      expect(abc.numbers?.two, 2);
      expect(abc.value, 'abc');
    });
  });
}
