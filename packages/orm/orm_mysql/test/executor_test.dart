import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';
import 'models/email_indexed.dart';
import 'models/unorthodox.dart';

/// The same queries through each executor: [MySqlExecutor], which stores a
/// `DateTime` as local time, and [MariaDbExecutor], which stores it as UTC.
void main() {
  mySqlQueueTests();
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

/// The queue of the commands of a connection of [MySqlExecutor], of which
/// `mysql_dart` runs one at a time.
void mySqlQueueTests() {
  late MySQLConnection conn;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openMySqlConnection();
    runner = await createTables(conn, [CarMigration()]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.connected) await conn.close();
  });

  group('MySqlExecutor queue', () {
    test('close closes once the queries given before have run', () async {
      var executor = MySqlExecutor(await openMySqlConnection());
      var inserts = [
        for (var i = 0; i < 4; i++)
          (CarQuery()..values.make = 'Make $i').insert(executor),
      ];
      await executor.close();
      var cars = await Future.wait(inserts);
      expect(
        [for (var car in cars) car.value.make],
        [for (var i = 0; i < 4; i++) 'Make $i'],
      );
    });

    test(
      'a transaction in one of another executor stores a DateTime as its own',
      () async {
        var connection = await openMySqlConnection();
        var mySql = MySqlExecutor(connection);
        var mariaDb = MariaDbExecutor(connection);
        // Local, as MySqlExecutor stores it, of the time zone of the host.
        var at = DateTime(2020, 1, 2, 3, 4, 5);
        try {
          await mariaDb.transaction((_) async {
            await mySql.transaction((tx) async {
              expect(tx, isNot(isA<MariaDbExecutor>()));
              await (CarQuery()
                    ..values.make = 'Local'
                    ..values.createdAt = at)
                  .insert(tx);
            });
          });
          var stored = await conn.execute(
            "SELECT created_at FROM cars WHERE make = 'Local'",
          );
          expect(stored.rows.single.colAt(0), '2020-01-02 03:04:05');
        } finally {
          await mySql.close();
        }
      },
    );

    test('the executor of an ended transaction runs no query', () async {
      var executor = MySqlExecutor(await openMySqlConnection());
      try {
        late QueryExecutor kept;
        await executor.transaction((tx) async => kept = tx);
        // As a timer of the transaction would, after it.
        await expectLater(
          (CarQuery()..values.make = 'Late').insert(kept),
          throwsStateError,
        );
        // The executor of the connection still runs.
        var car = await (CarQuery()..values.make = 'After').insert(executor);
        expect(car.value.make, 'After');
      } finally {
        await executor.close();
      }
    });
  });
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

    test('queries of a transaction sent at once each run', () async {
      var makes = await executor.transaction(
        (tx) => Future.wait([
          for (var i = 0; i < 6; i++)
            (CarQuery()..values.make = 'Make $i')
                .insert(tx)
                .then((car) => car.value.make),
        ]),
      );
      expect(makes, [for (var i = 0; i < 6; i++) 'Make $i']);
    });

    test('a transaction in a transaction is of it', () async {
      var car = await executor.transaction(
        (tx) => tx.transaction(
          (inner) => (CarQuery()..values.make = 'Nested').insert(inner),
        ),
      );
      expect(car.value.make, 'Nested');
      // And a delete in a transaction, which is one itself on MySQL.
      await executor.transaction(
        (tx) => (CarQuery()..where!.make.equals('Nested')).delete(tx),
      );
      expect(await CarQuery().get(executor), isEmpty);
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
      await (UnorthodoxQuery()..values.name = 'c').insert(executor);

      // Of the new value, which the conditions no longer match.
      var query = UnorthodoxQuery()
        ..where!.name.equals('a')
        ..values.name = 'b';
      var rows = await query.update(executor);
      expect(rows.map((r) => r.name), ['b']);
      var all = await UnorthodoxQuery().get(executor);
      expect(all.map((r) => r.name).toList()..sort(), ['b', 'c']);
    });

    test('insert into a table without an id of a null value', () async {
      // Returned as inserted, as `user_email = NULL` would select none.
      var tables = await createTables(conn, [
        RoleMigration(),
        UserMigration(),
        RoleUserMigration(),
      ]);
      try {
        await (RoleQuery()..values.role = 'admin').insert(executor);
        // Of a row of all nulls, the generated parseRow gives none.
        var row =
            (await (RoleUserQuery()
                      ..values.roleRole = 'admin'
                      ..values.userEmail = null)
                    .insert(executor))
                .value;
        expect(row.user, isNull);
        expect(await RoleUserQuery().get(executor), hasLength(1));
      } finally {
        await dropTables(tables);
      }
    });

    test('delete returns the deleted rows', () async {
      for (var make in ['Kept', 'Gone', 'Gone']) {
        await (CarQuery()..values.make = make).insert(executor);
      }
      var deleted = await (CarQuery()..where!.make.equals('Gone')).delete(
        executor,
      );
      expect(deleted.map((c) => c.make), ['Gone', 'Gone']);
      var left = await CarQuery().get(executor);
      expect(left.map((c) => c.make), ['Kept']);
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

    test('a DateTime is stored as of the executor, and read back', () async {
      var at = DateTime.utc(2020, 1, 2, 3, 4, 5);
      var car =
          (await (CarQuery()
                    ..values.make = 'Dated'
                    ..values.createdAt = at)
                  .insert(executor))
              .value;
      expect(car.createdAt!.isAtSameMomentAs(at), isTrue);
      // As UTC of a MariaDbExecutor, and as local time of a MySqlExecutor.
      var utc = executor is MariaDbExecutor;
      expect(car.createdAt!.isUtc, utc);
      var stored = await conn.execute(
        "SELECT created_at FROM cars WHERE make = 'Dated'",
      );
      var expected = utc ? at : at.toLocal();
      expect(
        stored.rows.single.colAt(0),
        startsWith(
          expected.toIso8601String().substring(0, 19).replaceAll('T', ' '),
        ),
      );
    });

    test(
      'the executor of a transaction is of the type of the executor',
      () async {
        await executor.transaction((tx) async {
          expect(tx.runtimeType, executor.runtimeType);
          // Which closes neither the transaction nor the connection.
          await expectLater((tx as MySqlExecutor).close(), throwsStateError);
        });
        expect(await CarQuery().get(executor), isEmpty);
      },
    );

    test('the executor of a connection runs in its transaction', () async {
      // Rather than wait for the transaction, which waits for it.
      await expectLater(
        executor
            .transaction((tx) async {
              await (CarQuery()..values.make = 'Outer').insert(executor);
              await executor.transaction(
                (inner) => (CarQuery()..values.make = 'Inner').insert(inner),
              );
              expect(await CarQuery().get(tx), hasLength(2));
              throw StateError('roll back');
            })
            .timeout(const Duration(seconds: 10)),
        throwsStateError,
      );
      expect(await CarQuery().get(executor), isEmpty);
    });

    test('queries not waited for run in their transaction', () async {
      var left = Completer<void>();
      await executor.transaction((tx) async {
        unawaited(
          (CarQuery()..values.make = 'Committed')
              .insert(tx)
              .then((_) => left.complete(), onError: left.completeError),
        );
      });
      await left.future;

      // Rolled back with it, rather than sent as its ROLLBACK is.
      var rolledBack = Completer<void>();
      await expectLater(
        executor
            .transaction((tx) async {
              unawaited(
                (CarQuery()..values.make = 'Rolled back')
                    .insert(tx)
                    .then(
                      (_) => rolledBack.complete(),
                      onError: rolledBack.completeError,
                    ),
              );
              throw StateError('roll back');
            })
            .timeout(const Duration(seconds: 10)),
        throwsStateError,
      );
      await rolledBack.future;

      var cars = await CarQuery().get(executor);
      expect(cars.map((c) => c.make), ['Committed']);
    });

    test('the connection is not closed in its transaction', () async {
      await executor.transaction((tx) async {
        await expectLater(
          (executor as MySqlExecutor).close(),
          throwsStateError,
        );
        await (CarQuery()..values.make = 'Open').insert(tx);
      });
      expect(await CarQuery().get(executor), hasLength(1));
    });

    test('a zero date is null', () async {
      await conn.execute("SET SESSION sql_mode = ''");
      await conn.execute(
        "INSERT INTO cars (make, created_at) VALUES ('Zero', '0000-00-00 00:00:00')",
      );
      var car = (await (CarQuery()..where!.make.equals('Zero')).getOne(
        executor,
      )).value;
      expect(car.createdAt, isNull);
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

    test('an invalid date is null, not another day', () async {
      await conn.execute("SET SESSION sql_mode = 'ALLOW_INVALID_DATES'");
      await conn.execute(
        "INSERT INTO cars (make, created_at) VALUES ('Invalid', '2024-02-30 00:00:00')",
      );
      var car = (await (CarQuery()..where!.make.equals('Invalid')).getOne(
        executor,
      )).value;
      expect(car.createdAt, isNull);
    });

    test('a date and time is read with its fields as stored', () async {
      // In the gap of a change to daylight saving time in America/New_York,
      // which a time read as local time there would move by an hour.
      await conn.execute(
        "INSERT INTO cars (make, created_at) VALUES ('Gap', '2024-03-10 02:30:00')",
      );
      var car = (await (CarQuery()..where!.make.equals('Gap')).getOne(executor))
          .value;
      var fields = executor is MariaDbExecutor
          ? DateTime.utc(2024, 3, 10, 2, 30)
          : DateTime(2024, 3, 10, 2, 30);
      expect(car.createdAt, fields);
    });

    test('operations not waited for run whole in their transaction', () async {
      for (var make in ['Deleted', 'Updated']) {
        await (CarQuery()..values.make = make).insert(executor);
      }
      var done = <Future>[];
      await executor.transaction((tx) async {
        // Each selects its rows first, then changes them, and selects them
        // again, after the callback has returned.
        done
          ..add((CarQuery()..where!.make.equals('Deleted')).delete(tx))
          ..add(
            (CarQuery()
                  ..where!.make.equals('Updated')
                  ..values.description = 'Changed')
                .update(tx),
          );
      });
      var results = await Future.wait(done);
      expect(results.map((cars) => cars.length), [1, 1]);
      var cars = await CarQuery().get(executor);
      expect(cars.map((c) => (c.make, c.description)), [
        ('Updated', 'Changed'),
      ]);
    });

    test('an insert id above the range of an int returns the row', () async {
      await conn.execute(
        'CREATE TABLE big_ids (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, '
        'name VARCHAR(16)) AUTO_INCREMENT = 9223372036854775808',
      );
      try {
        var rows = await executor.query(
          'big_ids',
          'INSERT INTO big_ids (name) VALUES (@name)',
          {'name': 'Big'},
          returningQuery:
              'SELECT id, name FROM big_ids WHERE id = @$insertIdParameter',
        );
        // The row of that id, which the driver gives as text.
        expect(rows.map((row) => row.map((v) => '$v')), [
          ['9223372036854775808', 'Big'],
        ]);
      } finally {
        await conn.execute('DROP TABLE big_ids');
      }
    });
  });
}
