import 'dart:async';
import 'dart:typed_data';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_sqlite/angel3_orm_sqlite.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';

void main() {
  for (var backend in backends) {
    group(backend.name, () => _tests(backend));
  }
}

void _tests(Backend backend) {
  late TestDatabase db;
  late QueryExecutor executor;

  setUp(() async {
    db = await backend.open();
    executor = db.executor;
    await db.execute('CREATE TABLE things (v)');
  });
  tearDown(() => db.close());

  Future<Car> insertCar(QueryExecutor on, String make) =>
      (CarQuery()
            ..values.make = make
            ..values.price = 1)
          .insert(on)
          .then((car) => car.value);

  Future<List<String?>> makes() => (CarQuery()..orderBy(CarFields.id))
      .get(executor)
      .then((cars) => [for (var c in cars) c.make]);

  Future<Object?> storeAndRead(Object? value) async {
    await executor.query('things', 'INSERT INTO things (v) VALUES (@v)', {
      'v': value,
    });
    var row = await db.select('SELECT v, typeof(v) AS t FROM things');
    return (row.single['v'], row.single['t']);
  }

  group('values', () {
    test('a Uint8List is a BLOB', () async {
      var bytes = Uint8List.fromList([1, 2, 3]);
      var (value, type) = await storeAndRead(bytes) as (Object?, Object?);
      expect(value, bytes);
      expect(type, 'blob');
    });

    test('a List<int> is JSON text, not bytes', () async {
      expect(await storeAndRead(<int>[1, 300]), ('[1,300]', 'text'));
    });

    test('a placeholder with no value throws', () {
      expect(
        executor.query('things', 'SELECT @nope', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a List of no ints is JSON text', () async {
      expect(await storeAndRead(<dynamic>[1, 'a']), ('[1,"a"]', 'text'));
    });

    test('a DateTime in JSON is text as it is stored', () async {
      var at = DateTime.utc(2024, 3, 10);
      expect(await storeAndRead({'at': at}), (
        '{"at":"2024-03-10 00:00:00.000000Z"}',
        'text',
      ));
    });

    test('a DateTime of a year after 9999 throws', () {
      expect(storeAndRead(DateTime.utc(10000)), throwsA(isA<ArgumentError>()));
    });
  });

  group('insert', () {
    test('returns the row by its id, which may not be its rowid', () async {
      var uuids = await backend.open(
        schema: '''
          CREATE TABLE cars (
            id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(8)))),
            created_at TEXT, updated_at TEXT, make TEXT, description TEXT,
            family_friendly BOOLEAN, recalled_at TEXT, price REAL
          )''',
      );
      var first = await insertCar(uuids.executor, 'A');
      var second = await insertCar(uuids.executor, 'B');
      expect(first.id, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect([first.make, second.make], ['A', 'B']);
      expect(second.id, isNot(first.id));
      await uuids.close();
    });

    test('of no row, as a trigger ignores it, returns none', () async {
      await insertCar(executor, 'A');
      await db.execute('''
        CREATE TRIGGER no_b BEFORE INSERT ON cars WHEN NEW.make = 'B'
        BEGIN SELECT RAISE(IGNORE); END''');
      var result = await (CarQuery()..values.make = 'B').insert(executor);
      expect(result.isPresent, isFalse);
    });
  });

  group('close', () {
    Future<void> close() => switch (executor) {
      SqliteExecutor e => e.close(),
      SqliteAsyncExecutor e => e.close(),
      _ => throw UnsupportedError('$executor'),
    };

    test('runs what is given before it, and refuses what is given after it, '
        'at once', () async {
      var release = Completer<void>();
      var transaction = executor.transaction((tx) async {
        await insertCar(tx, 'A');
        await release.future;
      });
      await Future<void>.delayed(Duration.zero);
      // Given outside the transaction before the close, which it may wait for.
      var before = insertCar(executor, 'B');
      var closed = close();
      expect(close(), same(closed));
      // Refused while the transaction still runs.
      await expectLater(CarQuery().get(executor), throwsStateError);
      await expectLater(
        executor.transaction((tx) => insertCar(tx, 'C')),
        throwsStateError,
      );
      expect(release.isCompleted, isFalse);
      release.complete();
      await transaction; // Committed.
      expect((await before).make, 'B');
      await closed.timeout(const Duration(seconds: 5));
    });
  });

  group('transaction', () {
    /// A transaction of [make] that waits between its statements, given
    /// outside the zone of any other, as by another request of a server.
    Future<void> slowTransaction(String make, {bool fail = false}) => runZoned(
      () => executor.transaction((tx) async {
        var car = await insertCar(tx, make);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await (CarQuery()
              ..where!.id.equals(int.parse(car.id!))
              ..values.price = 2)
            .update(tx);
        if (fail) {
          await insertCar(tx, 'X');
        }
      }),
    );

    test('two at the same time both commit, one after the other', () async {
      await Future.wait([slowTransaction('A'), slowTransaction('B')])
          .timeout(const Duration(seconds: 5));
      expect(await makes(), unorderedEquals(['A', 'B']));
      var prices = await CarQuery().get(executor);
      expect(prices.map((c) => c.price), [2, 2]);
    });

    test('rolled back by SQLite fails alone, not another', () async {
      await db.execute('''
        CREATE TRIGGER no_x BEFORE INSERT ON cars WHEN NEW.make = 'X'
        BEGIN SELECT RAISE(ROLLBACK, 'no X'); END''');
      Object? error;
      await Future.wait([
        slowTransaction('A'),
        slowTransaction('B', fail: true).catchError((Object e) => error = e),
      ]).timeout(const Duration(seconds: 5));
      expect(error, isA<SqliteException>());
      expect(await makes(), ['A']);
    });

    test(
      'rolled back by SQLite runs no statement given with the failing one',
      () async {
        await db.execute('''
        CREATE TRIGGER no_b BEFORE INSERT ON cars WHEN NEW.make = 'B'
        BEGIN SELECT RAISE(ROLLBACK, 'no B'); END''');
        await expectLater(
          executor.transaction(
            (tx) => Future.wait([
              insertCar(tx, 'A'),
              insertCar(tx, 'B'),
              insertCar(tx, 'C'),
            ], eagerError: false),
          ),
          throwsA(anything),
        );
        expect(await makes(), isEmpty);
        expect(await db.autocommit(), isTrue);
      },
    );

    test('runs the savepoints of concurrent writes one at a time', () async {
      for (var make in ['A', 'B', 'C']) {
        await insertCar(executor, make);
      }
      await executor.transaction(
        (tx) => Future.wait([
          (CarQuery()..where!.make.equals('A')).delete(tx),
          (CarQuery()
                ..where!.make.equals('B')
                ..values.make = 'Z')
              .update(tx),
          (CarQuery()..where!.make.equals('C')).delete(tx),
        ]),
      );
      expect(await makes(), ['Z']);
    });

    test('of a failing savepoint keeps the concurrent ones', () async {
      await executor.transaction((tx) async {
        var results = await Future.wait([
          insertCar(tx, 'A'),
          tx
              .transaction((tx) async {
                await insertCar(tx, 'B');
                throw StateError('fail');
              })
              .then((_) => null, onError: (_) => null),
          insertCar(tx, 'C'),
        ]);
        expect(results, hasLength(3));
      });
      expect(await makes(), ['A', 'C']);
    });

    test('runs the queries of its executor from another zone', () async {
      // A listener of a stream made before the transaction, in its zone.
      var requests = StreamController<(QueryExecutor, Completer<int>)>();
      requests.stream.listen((request) async {
        var (tx, completer) = request;
        completer.complete((await CarQuery().get(tx)).length);
      });
      await executor.transaction((tx) async {
        await insertCar(tx, 'A');
        var count = Completer<int>();
        requests.add((tx, count));
        expect(await count.future.timeout(const Duration(seconds: 2)), 1);
      });
      await requests.close();
    });

    test('of a savepoint uses it, given the executor of its parent', () async {
      await executor.transaction((tx) async {
        await tx.transaction((_) => insertCar(tx, 'A'));
      });
      expect(await makes(), ['A']);
    });

    test('runs a query given later in the zone of an ended savepoint in its parent', () async {
      await expectLater(
        executor
            .transaction((tx) async {
              var later = Completer<void>();
              await tx.transaction((_) async {
                // Runs after the savepoint has ended, in its zone.
                Timer(Duration.zero, () {
                  later.complete(insertCar(executor, 'A').then((_) {}));
                });
              });
              await later.future;
              expect(await makes(), ['A']);
              throw StateError('roll back');
            })
            .timeout(const Duration(seconds: 5)),
        throwsStateError,
      );
      expect(await makes(), isEmpty);
    });

    test('waits for the queries given in it that were not awaited', () async {
      await executor.transaction((tx) async {
        unawaited(insertCar(tx, 'A'));
      });
      expect(await makes(), ['A']);
    });

    test('its executor throws once it has ended', () async {
      late QueryExecutor ended;
      await executor.transaction((tx) => ended = tx);
      expect(CarQuery().get(ended), throwsStateError);
    });

    test('rolled back by SQLite fails, with the error of SQLite', () async {
      await db.execute('''
        CREATE TRIGGER no_b BEFORE INSERT ON cars WHEN NEW.make = 'B'
        BEGIN SELECT RAISE(ROLLBACK, 'no B'); END''');
      Object? inner;
      await expectLater(
        executor.transaction((tx) async {
          await insertCar(tx, 'A');
          try {
            // A savepoint, of the update, whose rollback SQLite has made.
            await tx.transaction((tx) => insertCar(tx, 'B'));
          } catch (e) {
            inner = e;
          }
          // Not run outside the transaction, which has ended.
          await insertCar(tx, 'C');
        }),
        throwsStateError,
      );
      expect(inner, isA<SqliteException>());
      expect((inner as SqliteException).message, contains('no B'));
      expect(await makes(), isEmpty);
      expect(await db.autocommit(), isTrue);
    });
  });
}
