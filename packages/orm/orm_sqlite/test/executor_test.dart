import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';
import 'models/leg.dart';

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
  });
  tearDown(() => db.close());

  Future<Car> insertCar(String make, {double price = 1, DateTime? recalled}) =>
      (CarQuery()
            ..values.make = make
            ..values.familyFriendly = true
            ..values.price = price
            ..values.recalledAt = recalled)
          .insert(executor)
          .then((car) => car.value);

  group('insert', () {
    test('returns the row with the id SQLite gave it', () async {
      var recalled = DateTime.utc(2024, 3, 10, 12, 34, 56, 789, 123);
      var car = await insertCar('Toyota', price: 9.5, recalled: recalled);
      expect(car.id, '1');
      expect(car.make, 'Toyota');
      expect(car.familyFriendly, isTrue);
      expect(car.price, 9.5);
      expect(car.recalledAt, recalled);

      var second = await insertCar('Honda');
      expect(second.id, '2');
    });

    test('stores a local DateTime as UTC', () async {
      var local = DateTime(2024, 3, 10, 12);
      var car = await insertCar('Toyota', recalled: local);
      expect(car.recalledAt!.isUtc, isTrue);
      expect(car.recalledAt, local.toUtc());
    });
  });

  group('select', () {
    test('filters, sorts, limits and offsets', () async {
      for (var (i, make) in ['A', 'B', 'C', 'D'].indexed) {
        await insertCar(make, price: i.toDouble());
      }
      var query = CarQuery()
        ..where!.price.greaterThan(0)
        ..orderBy(CarFields.price, descending: true)
        ..limit(2)
        ..offset(1);
      var cars = await query.get(executor);
      expect(cars.map((c) => c.make), ['C', 'B']);
    });

    test('compares a DateTime in time order', () async {
      await insertCar('Old', recalled: DateTime.utc(2020));
      await insertCar('New', recalled: DateTime.utc(2024, 1, 1, 0, 0, 0, 1));
      var query = CarQuery()..where!.recalledAt.lessThan(DateTime.utc(2024));
      expect((await query.get(executor)).map((c) => c.make), ['Old']);
    });

    test('joins a hasOne', () async {
      var leg = (await (LegQuery()..values.name = 'Left').insert(executor))
          .value;
      await (FootQuery()
            ..values.legId = int.parse(leg.id!)
            ..values.nToes = 5)
          .insert(executor);
      var found =
          (await (LegQuery()..where!.id.equals(int.parse(leg.id!))).getOne(
            executor,
          )).value;
      expect(found.name, 'Left');
      expect(found.foot?.nToes, 5);
    });
  });

  group('update', () {
    test('returns the rows updated', () async {
      await insertCar('A', price: 1);
      await insertCar('B', price: 2);
      var query = CarQuery()
        ..where!.price.lessThan(2)
        ..values.make = 'Z';
      var updated = await query.update(executor);
      expect(updated.map((c) => c.make), ['Z']);
      var all = await (CarQuery()..orderBy(CarFields.id)).get(executor);
      expect(all.map((c) => c.make), ['Z', 'B']);
    });

    test('of a limit updates only the rows it picks', () async {
      for (var make in ['A', 'B', 'C']) {
        await insertCar(make);
      }
      var query = CarQuery()
        ..orderBy(CarFields.make, descending: true)
        ..limit(1)
        ..values.price = 99;
      expect((await query.update(executor)).map((c) => c.make), ['C']);
      var expensive = CarQuery()..where!.price.equals(99);
      expect((await expensive.get(executor)).map((c) => c.make), ['C']);
    });
  });

  group('delete', () {
    test('returns the rows deleted', () async {
      await insertCar('A', price: 1);
      await insertCar('B', price: 2);
      var deleted = await (CarQuery()..where!.make.equals('A')).delete(
        executor,
      );
      expect(deleted.map((c) => c.make), ['A']);
      expect((await CarQuery().get(executor)).map((c) => c.make), ['B']);
    });
  });

  group('transaction', () {
    test('commits', () async {
      await executor.transaction((tx) => insertCar('A'));
      expect(await CarQuery().get(executor), hasLength(1));
    });

    test('rolls back when it fails', () async {
      await expectLater(
        executor.transaction((tx) async {
          await insertCar('A');
          throw StateError('fail');
        }),
        throwsStateError,
      );
      expect(await CarQuery().get(executor), isEmpty);
    });

    test('rolls back a nested transaction alone', () async {
      await executor.transaction((tx) async {
        await insertCar('A');
        await expectLater(
          tx.transaction((tx) async {
            await insertCar('B');
            throw StateError('fail');
          }),
          throwsStateError,
        );
      });
      expect((await CarQuery().get(executor)).map((c) => c.make), ['A']);
    });

    test('outside it, waits for it or reads the rows before it', () async {
      var inTransaction = executor.transaction((tx) async {
        await insertCar('A');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await insertCar('B');
      });
      // Given while the transaction runs, outside it.
      var count = await Future<void>.delayed(Duration.zero)
          .then((_) => CarQuery().get(executor))
          .then((cars) => cars.length);
      await inTransaction;
      // On one connection, it waits; on a pool, it reads on a connection of
      // its own, at the same time.
      expect(count, backend.readsWait ? 2 : 0);
    });

    test('of an update in a transaction is a savepoint of it', () async {
      await insertCar('A');
      await executor.transaction((tx) async {
        await (CarQuery()..values.make = 'B').update(tx);
        expect((await CarQuery().get(tx)).single.make, 'B');
      });
      expect((await CarQuery().get(executor)).single.make, 'B');
    });
  });

  test('has the SQLite dialect', () {
    expect(executor.dialect, isA<SqliteDialect>());
  });
}
