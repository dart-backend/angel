import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/priced.dart';

/// A numeric column keeps the precision and scale its model declares.
void main() {
  late MySQLConnection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [PricedMigration()]);
  });

  tearDown(() async {
    await dropTables(runner);
    await conn.close();
  });

  test('the column has the declared precision and scale', () async {
    var rows = await executor.query(
      'priceds',
      "SELECT numeric_precision, numeric_scale FROM information_schema.columns "
          "WHERE table_name = 'priceds' AND column_name = 'amount' AND table_schema = DATABASE()",
      {},
    );
    expect(rows, hasLength(1));
    expect(rows.single.map((v) => int.parse('$v')), [10, 2]);
  });

  test('a value keeps its two decimals', () async {
    var priced = (await (PricedQuery()..values.amount = 1234.56).insert(
      executor,
    )).value;
    expect(priced.amount, 1234.56);
  });
}
