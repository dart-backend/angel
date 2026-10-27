import 'dart:async';
import 'dart:io';

import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';

final DateTime y2k = DateTime(2000, 1, 1);

void main() {
  Logger.root.level = Level.INFO; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });

  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [CarMigration()]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) {
      await conn.close();
    }
  });

  group('queries', () {
    group('selects', () {
      test('select all', () async {
        var cars = await CarQuery().get(executor);
        expect(cars, []);
      });

      group('with data', () {
        Car? ferrari;

        setUp(() async {
          var query = CarQuery();
          query.values
            ..make = 'Ferrari東'
            ..createdAt = y2k
            ..updatedAt = y2k
            ..description = 'Vroom vroom!'
            ..price = 120000.00
            ..familyFriendly = false;
          ferrari = (await query.insert(executor)).value;
        });

        test('select of some fields reads each in its column', () async {
          var cars = await (CarQuery()..select(['make', 'price'])).get(
            executor,
          );
          expect(cars, hasLength(1));
          expect(cars.first.make, 'Ferrari東');
          expect(cars.first.price, 120000.00);
          expect(cars.first.description, isNull);
        });

        test('where clause is applied', () async {
          var query = CarQuery()..where!.familyFriendly.isTrue;
          var cars = await query.get(executor);
          expect(cars, isEmpty);

          var sportsCars = CarQuery()..where!.familyFriendly.isFalse;
          cars = await sportsCars.get(executor);
          print(cars.map((c) => c.toJson()));

          var car = cars.first;
          expect(car.make, ferrari!.make);
          expect(car.description, ferrari!.description);
          expect(car.familyFriendly, ferrari!.familyFriendly);
          expect(car.recalledAt, isNull);
        });

        test('union', () async {
          var query1 = CarQuery()..where?.make.like('%Fer%');
          var query2 = CarQuery()..where?.familyFriendly.isTrue;
          var query3 = CarQuery()..where?.description.equals('Submarine');
          var union = query1.union(query2).unionAll(query3);
          //print(union.compile({}));
          var cars = await union.get(executor);
          expect(cars, hasLength(1));
        });

        test('or clause', () async {
          var query = CarQuery()
            ..where!.make.like('Fer%')
            ..orWhere(
              (where) => where
                ..familyFriendly.isTrue
                ..make.equals('Honda'),
            );
          //print(query.compile({}));
          var cars = await query.get(executor);
          expect(cars, hasLength(1));
        });

        test('limit obeyed', () async {
          var query = CarQuery()..limit(0);
          //print(query.compile({}));
          var cars = await query.get(executor);
          expect(cars, isEmpty);
        });

        test('get one', () async {
          var id = int.parse(ferrari!.id!);
          var query = CarQuery()..where!.id.equals(id);
          var carOpt = await query.getOne(executor);
          expect(carOpt.isPresent, true);
          carOpt.ifPresent((car) {
            expect(car, ferrari);
          });
        });

        test('delete one', () async {
          var id = int.parse(ferrari!.id!);
          var query = CarQuery()..where!.id.equals(id);
          var carOpt = await query.deleteOne(executor);
          expect(carOpt.isPresent, true);
          carOpt.ifPresent((car) {
            var car = carOpt.value;
            expect(car.toJson(), ferrari!.toJson());
          });

          var cars = await CarQuery().get(executor);
          expect(cars, isEmpty);
        });

        test('delete stream', () async {
          var query = CarQuery()
            ..where!.make.equals('Ferrari東')
            ..orWhere((w) => w.familyFriendly.isTrue);
          //print(query.compile({}, preamble: 'DELETE FROM "cars"'));

          var cars = await query.delete(executor);
          expect(cars, hasLength(1));
          expect(cars.first.toJson(), ferrari!.toJson());
        });

        test('update', () async {
          var query = CarQuery()
            ..where!.id.equals(int.parse(ferrari!.id!))
            ..values.make = 'Hyundai';
          var cars = await query.update(executor);
          expect(cars, hasLength(1));
          expect(cars.first.make, 'Hyundai');
        });

        test('where on parts of a date', () async {
          // Fractional seconds must still match the whole second.
          // In UTC, as the driver stores it, so the year is that in any zone.
          var withSeconds = DateTime.utc(2000, 1, 1, 0, 0, 7, 500);
          var insert = CarQuery();
          insert.values
            ..make = 'Mazda'
            ..createdAt = withSeconds
            ..updatedAt = withSeconds
            ..description = 'Zoom zoom'
            ..price = 30000.00
            ..familyFriendly = true;
          var mazda = (await insert.insert(executor)).value;

          var query = CarQuery();
          query.where!.createdAt
            ..year.equals(withSeconds.year)
            ..second.equals(withSeconds.second);
          var cars = await query.get(executor);
          expect(cars.map((c) => c.id), [mazda.id]);

          query = CarQuery();
          query.where!.createdAt.year.equals(y2k.year + 1);
          expect(await query.get(executor), isEmpty);
        });

        test('update by a column it changes', () async {
          // The updated rows no longer match the condition, but are returned.
          var query = CarQuery()
            ..where!.make.equals('Ferrari東')
            ..values.make = 'Hyundai';
          var cars = await query.update(executor);
          expect(cars, hasLength(1));
          expect(cars.first.make, 'Hyundai');
        });

        test('update with a limit', () async {
          await (CarQuery()
                ..values.make = 'Ferrari東'
                ..values.description = 'Second'
                ..values.familyFriendly = false)
              .insert(executor);
          var query = CarQuery()
            ..where!.make.equals('Ferrari東')
            ..values.description = 'Limited'
            ..limit(1);
          var cars = await query.update(executor);
          expect(cars, hasLength(1));
          expect(cars.single.description, 'Limited');
          var limited = await (CarQuery()..where!.description.equals('Limited'))
              .get(executor);
          expect(limited, hasLength(1));
        });

        test('update car', () async {
          var cloned = ferrari!.copyWith(make: 'Angel');
          var query = CarQuery()..values.copyFrom(cloned);
          var carOpt = await (query.updateOne(executor));
          expect(carOpt.isPresent, true);
          carOpt.ifPresent((car) {
            var car = carOpt.value;
            //print(car.toJson());
            expect(car.toJson(), cloned.toJson());
          });
        });
      });
    });

    test('insert', () async {
      var recalledAt = DateTime.utc(2000, 1, 1, 0, 0, 0, 0, 0);
      var query = CarQuery();
      var now = DateTime.now();
      query.values
        ..make = 'Honda'
        ..description = 'Hello'
        ..familyFriendly = true
        ..recalledAt = recalledAt
        ..createdAt = now
        ..updatedAt = now;
      var carOpt = await (query.insert(executor));
      expect(carOpt.isPresent, true);
      carOpt.ifPresent((car) {
        var car = carOpt.value;
        expect(car.id, isNotNull);
        expect(car.make, 'Honda');
        expect(car.description, 'Hello');
        expect(car.familyFriendly, isTrue);
        expect(
          dateYmdHms.format(car.recalledAt!),
          dateYmdHms.format(recalledAt),
        );
        expect(dateYmdHms.format(car.createdAt!), dateYmdHms.format(now));
      });
    });

    test('insert car', () async {
      var recalledAt = DateTime.now();
      var beetle = Car(
        make: 'Beetle',
        description: 'Herbie',
        familyFriendly: true,
        recalledAt: recalledAt,
      );
      var query = CarQuery()..values.copyFrom(beetle);
      var carOpt = await (query.insert(executor));
      expect(carOpt.isPresent, true);
      carOpt.ifPresent((car) {
        //print(car.toJson());
        expect(car.make, beetle.make);
        expect(car.description, beetle.description);
        expect(car.familyFriendly, beetle.familyFriendly);
        expect(
          dateYmdHms.format(car.recalledAt!),
          dateYmdHms.format(beetle.recalledAt!),
        );
      });
    });
    test('to where', () {
      var query = CarQuery();
      query.where
        ?..familyFriendly.isTrue
        ..recalledAt.lessThanOrEqualTo(y2k, includeTime: false);
      var whereClause = query.where?.compile(tableName: 'cars');
      //print('Where clause: $whereClause');
      expect(
        whereClause,
        'cars.family_friendly = TRUE AND cars.recalled_at <= \'2000-01-01\'',
      );
    });

    test('parseRow', () {
      // 'id', 'created_at',  'updated_at', 'make', 'description', 'family_friendly', 'recalled_at'
      // var row = [0, 'Mazda', 'CX9', true, y2k, y2k, y2k];
      var row = [0, y2k, y2k, 'Mazda', 'CX9', true, y2k, 80000.00];
      //print(row);
      var carOpt = CarQuery().deserialize(row);
      expect(carOpt.isPresent, true);
      carOpt.ifPresent((car) {
        //print(car.toJson());
        expect(car.id, '0');
        expect(car.make, 'Mazda');
        expect(car.description, 'CX9');
        expect(car.familyFriendly, true);
        expect(
          y2k.toIso8601String(),
          startsWith(car.recalledAt!.toIso8601String()),
        );
        expect(
          y2k.toIso8601String(),
          startsWith(car.createdAt!.toIso8601String()),
        );
        expect(
          y2k.toIso8601String(),
          startsWith(car.updatedAt!.toIso8601String()),
        );
        expect(car.price, 80000.00);
      });
    });
  });

  // In this file, as it shares the cars table with the tests above, which
  // test files that run at the same time cannot.
  group('transaction', () {
    Future<Car> insertCar(QueryExecutor executor, String make) async {
      var insert = CarQuery();
      insert.values
        ..make = make
        ..description = 'A car'
        ..familyFriendly = true
        ..price = 1
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      return (await insert.insert(executor)).value;
    }

    Future<List<String?>> makes() async =>
        (await CarQuery().get(executor)).map((c) => c.make).toList();

    test('commits what its callback does', () async {
      await executor.transaction((tx) => insertCar(tx, 'Committed'));
      expect(await makes(), ['Committed']);
    });

    group('an error of its callback', () {
      test('of its own is thrown as it is, and rolls back', () async {
        await expectLater(
          executor.transaction((tx) async {
            await insertCar(tx, 'Rolled back');
            throw ArgumentError('of the callback');
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'of the callback',
            ),
          ),
        );
        expect(await makes(), isEmpty);
      });

      test('of the database is thrown as it is, and rolls back', () async {
        await expectLater(
          executor.transaction((tx) async {
            await insertCar(tx, 'Rolled back');
            await tx.query('cars', 'SELECT 1/0', {});
          }),
          throwsA(isA<PgException>()),
        );
        expect(await makes(), isEmpty);
      });
    });

    test(
      'in its callback is committed with the transaction it is in',
      () async {
        await expectLater(
          executor.transaction((tx) async {
            await tx.transaction((inner) => insertCar(inner, 'Inner'));
            throw StateError('after the inner one');
          }),
          throwsStateError,
        );
        // Rolled back with the outer one, as it is part of it.
        expect(await makes(), isEmpty);

        await executor.transaction(
          (tx) => tx.transaction((inner) => insertCar(inner, 'Inner')),
        );
        expect(await makes(), ['Inner']);
      },
    );

    group('in its callback is rolled back on its own', () {
      test('when it throws an error of its own', () async {
        await executor.transaction((tx) async {
          await insertCar(tx, 'Outer');
          try {
            await tx.transaction((inner) async {
              await insertCar(inner, 'Inner');
              throw ArgumentError('of the inner one');
            });
          } on ArgumentError {
            // Caught, so the outer one goes on.
          }
        });
        expect(await makes(), ['Outer']);
      });

      test(
        'when the database fails, which the outer one goes on after',
        () async {
          await executor.transaction((tx) async {
            await insertCar(tx, 'Outer');
            try {
              await tx.transaction((inner) async {
                await insertCar(inner, 'Inner');
                await inner.query('cars', 'SELECT 1/0', {});
              });
            } on PgException {
              // Caught, so the outer one goes on.
            }
            await insertCar(tx, 'After');
          });
          expect(await makes(), unorderedEquals(['Outer', 'After']));
        },
      );
    });

    test('in a savepoint, on the executor around it, does not hang', () async {
      await executor
          .transaction(
            (tx) => tx.transaction(
              (inner) => tx.transaction((deep) => insertCar(deep, 'Deep')),
            ),
          )
          .timeout(const Duration(seconds: 10));
      expect(await makes(), ['Deep']);
    });

    test(
      'in its callback that catches an error of the database is rolled back',
      () async {
        await executor.transaction((tx) async {
          await insertCar(tx, 'Outer');
          await expectLater(
            tx.transaction((inner) async {
              await insertCar(inner, 'Inner');
              try {
                await inner.query('cars', 'SELECT 1/0', {});
              } on PgException {
                // Caught here, which leaves the transaction aborted.
              }
            }),
            throwsA(isA<PgException>()),
          );
          await insertCar(tx, 'After');
        });
        expect(await makes(), unorderedEquals(['Outer', 'After']));
      },
    );

    test('of a pool executor behaves as that of a connection', () async {
      var pool = Pool.withEndpoints([
        Endpoint(
          host: Platform.environment['POSTGRES_HOSTNAME'] ?? 'localhost',
          database: Platform.environment['POSTGRES_DB'] ?? 'postgres',
          username: Platform.environment['POSTGRES_USERNAME'] ?? 'postgres',
          password: Platform.environment['POSTGRES_PASSWORD'] ?? 'postgres',
        ),
      ], settings: PoolSettings(sslMode: SslMode.disable));
      addTearDown(pool.close);
      var poolExecutor = PostgreSqlPoolExecutor(pool);

      await poolExecutor.transaction((tx) => insertCar(tx, 'Committed'));
      await expectLater(
        poolExecutor.transaction((tx) async {
          await insertCar(tx, 'Rolled back');
          throw ArgumentError('of the callback');
        }),
        throwsArgumentError,
      );
      await poolExecutor.transaction((tx) async {
        try {
          await tx.transaction((inner) async {
            await insertCar(inner, 'Savepoint');
            throw ArgumentError('of the savepoint');
          });
        } on ArgumentError {
          // Caught, so the transaction goes on.
        }
        await insertCar(tx, 'After');
      });
      expect(await makes(), unorderedEquals(['Committed', 'After']));
    });

    group('in a savepoint, two at a time, keep apart', () {
      // The first one throws while the second one would run, if they ran at
      // the same time; only the second one's work is kept.
      Future<List<String>> two(QueryExecutor first, QueryExecutor second) =>
          Future.wait([
            first
                .transaction((x) async {
                  await insertCar(x, 'Failed');
                  await Future.delayed(const Duration(milliseconds: 100));
                  throw ArgumentError('of the first one');
                })
                .then((_) => 'committed', onError: (_) => 'rolled back'),
            second
                .transaction((x) => insertCar(x, 'Kept'))
                .then((_) => 'committed', onError: (_) => 'rolled back'),
          ]);

      test('on the executor around it', () async {
        await executor.transaction(
          (tx) => tx.transaction((inner) async {
            expect(await two(tx, tx), ['rolled back', 'committed']);
          }),
        );
        expect(await makes(), ['Kept']);
      });

      test('on the executors around it and of it', () async {
        await executor.transaction(
          (tx) => tx.transaction((inner) async {
            expect(await two(inner, tx), ['rolled back', 'committed']);
          }),
        );
        expect(await makes(), ['Kept']);
      });
    });

    test('in its callback, two at a time, keep apart', () async {
      await executor.transaction((tx) async {
        var results = await Future.wait([
          tx
              .transaction((inner) async {
                await insertCar(inner, 'Failed');
                // While the other one runs, if they ran at the same time.
                await Future.delayed(const Duration(milliseconds: 100));
                throw ArgumentError('of the first one');
              })
              .then((_) => 'committed', onError: (_) => 'rolled back'),
          tx
              .transaction((inner) => insertCar(inner, 'Kept'))
              .then((_) => 'committed', onError: (_) => 'rolled back'),
        ]);
        expect(results, ['rolled back', 'committed']);
      });
      expect(await makes(), ['Kept']);
    });

    group('waits for a savepoint its callback does not await', () {
      test('in a savepoint', () async {
        await executor
            .transaction(
              (tx) => tx.transaction((outer) async {
                unawaited(
                  outer.transaction((inner) async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    await insertCar(inner, 'Inner');
                  }),
                );
              }),
            )
            .timeout(const Duration(seconds: 10));
        expect(await makes(), ['Inner']);
      });

      test('in the transaction', () async {
        await executor
            .transaction((tx) async {
              unawaited(
                tx.transaction((inner) async {
                  await Future.delayed(const Duration(milliseconds: 100));
                  await insertCar(inner, 'Inner');
                }),
              );
            })
            .timeout(const Duration(seconds: 10));
        expect(await makes(), ['Inner']);
      });
    });

    test('in a savepoint after it ended runs in the one around it', () async {
      await executor
          .transaction((tx) async {
            await tx.transaction((first) async {
              // Fires while the second one runs.
              Timer(const Duration(milliseconds: 50), () {
                unawaited(tx.transaction((x) => insertCar(x, 'Late')));
              });
            });
            await expectLater(
              tx.transaction((second) async {
                await Future.delayed(const Duration(milliseconds: 100));
                throw ArgumentError('of the second one');
              }),
              throwsArgumentError,
            );
          })
          .timeout(const Duration(seconds: 10));
      // Not rolled back with the second one, which it is not part of.
      expect(await makes(), ['Late']);
    });

    test(
      'on the connection from inside its callback throws, not hangs',
      () async {
        await expectLater(
          executor
              .transaction((tx) => executor.transaction((_) async => null))
              .timeout(const Duration(seconds: 10)),
          throwsA(isNot(isA<TimeoutException>())),
        );
      },
    );
  });
}
