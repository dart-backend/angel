import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';
import 'models/unorthodox.dart';

/// The same queries through each executor: [MySqlExecutor] (`mysql_dart`,
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

    test('insert with an id the database does not generate', () async {
      // A key of no AUTO_INCREMENT, as a UUID, of which there is no insert
      // id, so the row is found by the id given.
      await conn.execute('ALTER TABLE cars MODIFY id varchar(36) NOT NULL');
      var car =
          (await (CarQuery()
                    ..values.id = '0b9e2c4e-uuid'
                    ..values.make = 'Volvo')
                  .insert(executor))
              .value;
      expect(car.id, '0b9e2c4e-uuid');
      expect(car.make, 'Volvo');
    });

    test('inserts of two connections each return their own row', () async {
      // Not the last row by id, which may be the other connection's.
      var other = await open();
      try {
        var makes = [for (var i = 0; i < 10; i++) 'Make $i'];
        var cars = await Future.wait([
          for (var (i, make) in makes.indexed)
            (CarQuery()..values.make = make).insert(
              i.isEven ? executor : other,
            ),
        ]);
        expect([for (var car in cars) car.value.make], makes);
      } finally {
        await close(other);
      }
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

    test('values are stored as given, even if they look like SQL', () async {
      // `mysql_dart` binds named parameters as those of a prepared statement.
      var car =
          (await (CarQuery()
                    ..values.make = "it's :description :p1 @make"
                    ..values.description = ':p0'
                    ..values.familyFriendly = true)
                  .insert(executor))
              .value;
      expect(car.make, "it's :description :p1 @make");
      expect(car.description, ':p0');
      expect(car.familyFriendly, isTrue);
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
