import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';
import 'models/unorthodox.dart';

/// The same queries through each executor: [MySqlExecutor] (`mysql_client`,
/// named `:name` parameters) and [MariaDbExecutor] (`mysql1`, positional `?`
/// parameters).
void main() {
  executorTests(
    'MySqlExecutor',
    () async => MySqlExecutor(await openMySqlConnection()),
    (executor) => (executor as MySqlExecutor).close(),
  );
  executorTests(
    'MariaDbExecutor',
    openMariaDbExecutor,
    (executor) => (executor as MariaDbExecutor).close(),
  );
}

void executorTests(
  String name,
  Future<QueryExecutor> Function() open,
  Future<void> Function(QueryExecutor) close,
) {
  late MySQLConnection conn;
  late MigrationRunner runner;
  late QueryExecutor executor;

  setUp(() async {
    conn = await openMySqlConnection();
    runner = await createTables(conn, [CarMigration(), UnorthodoxMigration()]);
    executor = await open();
  });

  tearDown(() async {
    await close(executor);
    await dropTables(runner);
    if (conn.connected) {
      await conn.close();
    }
  });

  group(name, () {
    test('insert without an id returns the row', () async {
      var car =
          (await (CarQuery()
                    ..values.make = 'Ferrari'
                    ..values.familyFriendly = false)
                  .insert(executor))
              .value;
      expect(car.id, isNotNull);
      expect(car.make, 'Ferrari');
    });

    test('insert with an id returns that row', () async {
      var car =
          (await (CarQuery()
                    ..values.id = '42'
                    ..values.make = 'Mazda')
                  .insert(executor))
              .value;
      expect(car.id, '42');
      expect(car.make, 'Mazda');
    });

    test('insert into a table without an id returns the row', () async {
      var row = (await (UnorthodoxQuery()..values.name = 'Ünorthodox').insert(
        executor,
      )).value;
      expect(row.name, 'Ünorthodox');
    });

    test('update a table without an id returns the updated rows', () async {
      await (UnorthodoxQuery()..values.name = 'a').insert(executor);

      var query = UnorthodoxQuery()
        ..where!.name.equals('a')
        ..values.name = 'a';
      var rows = await query.update(executor);
      expect(rows.map((r) => r.name), ['a']);
    });

    test('placeholders of the same column are each bound', () async {
      for (var make in ['Ferrari', 'Mazda', 'Hyundai']) {
        await (CarQuery()..values.make = make).insert(executor);
      }

      // The two conditions reserve `@make` and `@make1`.
      var query = CarQuery()
        ..where!.make.equals('Mazda')
        ..orWhere((w) => w.make.equals('Hyundai'));
      var cars = await query.get(executor);
      expect(cars.map((c) => c.make), unorderedEquals(['Mazda', 'Hyundai']));
    });

    test('update by id returns the updated row', () async {
      var car = (await (CarQuery()..values.make = 'Ferrari').insert(executor))
          .value;

      var query = CarQuery()
        ..where!.id.equals(int.parse(car.id!))
        ..values.make = 'Hyundai';
      var cars = await query.update(executor);
      expect(cars.map((c) => c.make), ['Hyundai']);
    });
  });
}
