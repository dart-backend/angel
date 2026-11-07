import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';
import 'models/tree.dart';

/// That the SQL of a query is accepted by the database, and does what it says.
void main() {
  late MySQLConnection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      CarMigration(),
      TreeMigration(),
      FruitMigration(),
    ]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.connected) await conn.close();
  });

  Future<void> insertCars(List<String> descriptions) async {
    for (var description in descriptions) {
      await (CarQuery()
            ..values.make = 'x'
            ..values.description = description
            ..values.familyFriendly = false)
          .insert(executor);
    }
  }

  Future<List<String?>> descriptions() async => [
    for (var car in await (CarQuery()..orderBy('description')).get(executor))
      car.description,
  ];

  group('delete', () {
    setUp(() => insertCars(['a', 'b', 'c']));

    test('of a limit, after an offset, in order', () async {
      var deleted =
          await (CarQuery()
                ..orderBy('description', descending: true)
                ..limit(1)
                ..offset(1))
              .delete(executor);
      expect(deleted.map((c) => c.description), ['b']);
      expect(await descriptions(), ['a', 'c']);
    });

    test('with conditions and a limit', () async {
      var deleted =
          await (CarQuery()
                ..where!.description.notEquals('a')
                ..orderBy('description')
                ..limit(1))
              .delete(executor);
      expect(deleted.map((c) => c.description), ['b']);
      expect(await descriptions(), ['a', 'c']);
    });

    test('of an inner join deletes only the rows it returns', () async {
      await (FruitQuery()..values.commonName = 'c').insert(executor);
      var deleted =
          await (CarQuery()
                ..join('fruits', 'description', 'common_name')
                ..limit(1))
              .delete(executor);
      expect(deleted.map((c) => c.description), ['c']);
      expect(await descriptions(), ['a', 'b']);
    });

    test('of an inner join, without a limit, too', () async {
      await (FruitQuery()..values.commonName = 'b').insert(executor);
      var deleted =
          await (CarQuery()..join('fruits', 'description', 'common_name'))
              .delete(executor);
      expect(deleted.map((c) => c.description), ['b']);
      expect(await descriptions(), ['a', 'c']);
    });

    test('of a left join that repeats a row deletes it once', () async {
      for (var i = 0; i < 2; i++) {
        await (FruitQuery()..values.commonName = 'b').insert(executor);
      }
      var deleted =
          await (CarQuery()
                ..where!.description.equals('b')
                ..leftJoin('fruits', 'description', 'common_name'))
              .delete(executor);
      expect(deleted, isNotEmpty);
      expect(await descriptions(), ['a', 'c']);
    });

    test('of a relation, with a limit, returns the row it deletes', () async {
      for (var rings in [1, 2]) {
        var tree = await (TreeQuery()..values.rings = rings).insert(executor);
        await (FruitQuery()
              ..values.treeId = int.parse(tree.value.id!)
              ..values.commonName = 'fig$rings')
            .insert(executor);
      }
      var deleted =
          await (TreeQuery()
                ..orderBy('rings', descending: true)
                ..limit(1))
              .delete(executor);
      expect(deleted.single.rings, 2);
      expect(deleted.single.fruits.map((f) => f.commonName), ['fig2']);
      var left = await TreeQuery().get(executor);
      expect(left.map((t) => t.rings), [1]);
    });

    test('with an order and no limit returns every row in order', () async {
      var deleted = await (CarQuery()..orderBy('description', descending: true))
          .delete(executor);
      expect(deleted.map((c) => c.description), ['c', 'b', 'a']);
      expect(await descriptions(), isEmpty);
    });
  });

  group('a limit in the order of a join', () {
    setUp(() async {
      await insertCars(['a', 'b', 'c']);
      for (var name in ['b', 'c']) {
        await (FruitQuery()..values.commonName = name).insert(executor);
      }
    });

    test('updates the first rows of the join', () async {
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..join('fruits', 'description', 'common_name', alias: 'j')
                ..orderBy('j.common_name')
                ..limit(1))
              .update(executor);
      expect(updated.map((c) => c.description), ['b']);
      var made = await (CarQuery()..where!.make.equals('y')).get(executor);
      expect(made.map((c) => c.description), ['b']);
    });

    test('deletes the first rows of the join', () async {
      var deleted =
          await (CarQuery()
                ..join('fruits', 'description', 'common_name', alias: 'j')
                ..orderBy('j.common_name', descending: true)
                ..limit(1))
              .delete(executor);
      expect(deleted.map((c) => c.description), ['c']);
      expect(await descriptions(), ['a', 'b']);
    });
  });

  test('a part of a date with isIn of no values', () async {
    await insertCars(['a']);
    await (CarQuery()..values.make = 'dated').update(executor);
    var none = CarQuery()..where!.createdAt.year.isIn([]);
    expect(await none.get(executor), isEmpty);
    var all = CarQuery()..where!.createdAt.year.isNotIn([]);
    expect(await all.get(executor), hasLength(1));
  });

  group('update of a join, without a limit', () {
    setUp(() async {
      await insertCars(['a', 'b']);
      await (FruitQuery()..values.commonName = 'b').insert(executor);
    });

    Future<List<String?>> made() async => [
      for (var car
          in await (CarQuery()
                ..where!.make.equals('y')
                ..orderBy('description'))
              .get(executor))
        car.description,
    ];

    test('of an inner join updates only the rows it returns', () async {
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..join('fruits', 'description', 'common_name'))
              .update(executor);
      expect(updated.map((c) => c.description), ['b']);
      expect(await made(), ['b']);
    });

    test('of an inner join that repeats a row updates it once', () async {
      await (FruitQuery()..values.commonName = 'b').insert(executor);
      await (CarQuery()
            ..values.make = 'y'
            ..join('fruits', 'description', 'common_name'))
          .update(executor);
      expect(await made(), ['b']);
    });

    test('of a left join updates every row', () async {
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..leftJoin('fruits', 'description', 'common_name'))
              .update(executor);
      expect(updated, hasLength(2));
      expect(await made(), ['a', 'b']);
    });
  });

  group('the rows picked', () {
    setUp(() async {
      await insertCars(['a', 'b', 'c']);
      for (var name in ['a', 'b', 'c']) {
        await (FruitQuery()..values.commonName = name).insert(executor);
      }
    });

    test('by an order of a column it does not select, on delete', () async {
      var deleted =
          await (CarQuery()
                ..select(['id', 'make'])
                ..orderBy('description', descending: true)
                ..limit(1))
              .delete(executor);
      expect(deleted, hasLength(1));
      expect(await descriptions(), ['a', 'b']);
    });

    test('by an order of a column it does not select, on update', () async {
      var updated =
          await (CarQuery()
                ..select(['id', 'make'])
                ..values.make = 'y'
                ..orderBy('description', descending: true)
                ..limit(1))
              .update(executor);
      expect(updated, hasLength(1));
      var made = await (CarQuery()..where!.make.equals('y')).get(executor);
      expect(made.map((c) => c.description), ['c']);
    });

    test('by an order of a column a join has too', () async {
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..join('fruits', 'description', 'common_name')
                ..orderBy('id', descending: true)
                ..limit(1))
              .update(executor);
      expect(updated.map((c) => c.description), ['c']);
      var made = await (CarQuery()..where!.make.equals('y')).get(executor);
      expect(made.map((c) => c.description), ['c']);
    });

    test('by a raw condition on a left join, on update', () async {
      await (FruitQuery()..where!.commonName.equals('a')).delete(executor);
      var query = CarQuery()
        ..values.make = 'y'
        ..leftJoin('fruits', 'description', 'common_name', alias: 'f');
      query.where!.raw('f.common_name IS NULL');
      var updated = await query.update(executor);
      expect(updated.map((c) => c.description), ['a']);
      var made = await (CarQuery()..where!.make.equals('y')).get(executor);
      expect(made.map((c) => c.description), ['a']);
    });

    test('by a raw condition on a left join, on delete', () async {
      await (FruitQuery()..where!.commonName.equals('a')).delete(executor);
      var query = CarQuery()
        ..leftJoin('fruits', 'description', 'common_name', alias: 'f');
      query.where!.raw('f.common_name IS NULL');
      var deleted = await query.delete(executor);
      expect(deleted.map((c) => c.description), ['a']);
      expect(await descriptions(), ['b', 'c']);
    });
  });

  group('a join that adds rows', () {
    setUp(() async {
      await insertCars(['a']);
      for (var name in ['a', 'z']) {
        await (FruitQuery()..values.commonName = name).insert(executor);
      }
    });

    CarQuery rightJoined() => CarQuery()
      ..rightJoin(
        'fruits',
        'description',
        'common_name',
        alias: 'f',
        additionalFields: const ['common_name'],
      );

    test('returns only the rows an update wrote', () async {
      var updated = await (rightJoined()..values.make = 'y').update(executor);
      expect(updated.map((c) => c.description), ['a']);
    });

    test('counts only the rows of the table in a limit', () async {
      var updated =
          await (rightJoined()
                ..values.make = 'y'
                ..orderBy('f.common_name', descending: true)
                ..limit(1))
              .update(executor);
      expect(updated.map((c) => c.description), ['a']);
    });

    test('returns only the rows a delete removed', () async {
      var deleted = await rightJoined().delete(executor);
      expect(deleted.map((c) => c.description), ['a']);
      expect(await descriptions(), isEmpty);
    });
  });

  group('a cross join', () {
    setUp(() => insertCars(['a', 'b']));

    test('of an empty table updates nothing', () async {
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..crossJoin('fruits'))
              .update(executor);
      expect(updated, isEmpty);
      expect(
        await (CarQuery()..where!.make.equals('y')).get(executor),
        isEmpty,
      );
    });

    test('of an empty table deletes nothing', () async {
      expect(await (CarQuery()..crossJoin('fruits')).delete(executor), isEmpty);
      expect(await descriptions(), ['a', 'b']);
    });

    group('of a table with rows', () {
      setUp(() => (FruitQuery()..values.commonName = 'f').insert(executor));

      test('updates each row', () async {
        var updated =
            await (CarQuery()
                  ..values.make = 'y'
                  ..crossJoin('fruits'))
                .update(executor);
        expect(updated, hasLength(2));
      });

      test('with a limit, in an order of a column it has too', () async {
        var updated =
            await (CarQuery()
                  ..values.make = 'y'
                  ..crossJoin('fruits')
                  ..orderBy('id', descending: true)
                  ..limit(1))
                .update(executor);
        expect(updated.map((c) => c.description), ['b']);
      });

      test('deletes each row', () async {
        var deleted = await (CarQuery()..crossJoin('fruits')).delete(executor);
        expect(deleted, hasLength(2));
        expect(await descriptions(), isEmpty);
      });
    });
  });

  group('two connections on the rows of a limit', () {
    late MySQLConnection other;
    late QueryExecutor otherExecutor;

    setUp(() async {
      other = await openMySqlConnection();
      otherExecutor = await createExecutor(other);
      await insertCars(['a', 'b']);
    });

    tearDown(() => other.close());

    test('update different rows', () async {
      CarQuery next() => CarQuery()
        ..where!.make.equals('x')
        ..values.make = 'y'
        ..orderBy('description')
        ..limit(1);
      var claimed = await Future.wait([
        next().update(executor),
        next().update(otherExecutor),
      ]);
      expect([
        for (var cars in claimed) ...cars.map((c) => c.description),
      ], unorderedEquals(['a', 'b']));
    });

    test('delete different rows', () async {
      CarQuery next() => CarQuery()
        ..where!.make.equals('x')
        ..orderBy('description')
        ..limit(1);
      var claimed = await Future.wait([
        next().delete(executor),
        next().delete(otherExecutor),
      ]);
      expect([
        for (var cars in claimed) ...cars.map((c) => c.description),
      ], unorderedEquals(['a', 'b']));
    });
  });

  group('the rows a statement returns', () {
    test('of an update that breaks its join has the row', () async {
      await insertCars(['a']);
      await (FruitQuery()..values.commonName = 'a').insert(executor);
      var updated =
          await (CarQuery()
                ..values.description = 'gone'
                ..join('fruits', 'description', 'common_name'))
              .update(executor);
      expect(updated.map((c) => c.description), ['gone']);
      expect(await descriptions(), ['gone']);
    });

    test('of a cross join has each row once', () async {
      await insertCars(['a']);
      for (var name in ['f', 'g', 'h']) {
        await (FruitQuery()..values.commonName = name).insert(executor);
      }
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..crossJoin('fruits'))
              .update(executor);
      expect(updated.map((c) => c.description), ['a']);
    });

    test('of a join of its own table has the row', () async {
      await (CarQuery()
            ..values.make = 'b'
            ..values.description = 'a'
            ..values.familyFriendly = false)
          .insert(executor);
      await (CarQuery()
            ..values.make = 'x'
            ..values.description = 'b'
            ..values.familyFriendly = false)
          .insert(executor);
      var query = CarQuery()
        ..values.familyFriendly = true
        ..selfJoin('cars', 'make', 'description', alias: 'm')
        ..limit(1);
      var updated = await query.update(executor);
      expect(updated.map((c) => c.description), ['a']);
    });

    test('of an insert that joins nothing has the row', () async {
      var query = CarQuery()
        ..values.make = 'x'
        ..values.description = 'new'
        ..values.familyFriendly = false
        ..join('fruits', 'description', 'common_name');
      var inserted = await query.insert(executor);
      expect(inserted.value.description, 'new');
    });
  });

  test('update of a limit takes the first rows in order', () async {
    await insertCars(['a', 'b', 'c']);
    var updated =
        await (CarQuery()
              ..values.make = 'y'
              ..orderBy('description', descending: true)
              ..limit(1))
            .update(executor);
    expect(updated.map((c) => c.description), ['c']);
    var made = await (CarQuery()..where!.make.equals('y')).get(executor);
    expect(made.map((c) => c.description), ['c']);
  });

  test('insert ignores the conditions of the query', () async {
    var inserted =
        await (CarQuery()
              ..where!.make.equals('other')
              ..values.make = 'x'
              ..values.familyFriendly = false)
            .insert(executor);
    expect(inserted.isPresent, isTrue);
    expect(inserted.value.make, 'x');
  });

  group('isIn and isNotIn of no values', () {
    setUp(() => insertCars(['a']));

    test('match no row and every row, of a string', () async {
      expect(await (CarQuery()..where!.make.isIn([])).get(executor), isEmpty);
      expect(
        await (CarQuery()..where!.make.isNotIn([])).get(executor),
        hasLength(1),
      );
    });

    test('match no row and every row, of a number', () async {
      expect(await (CarQuery()..where!.price.isIn([])).get(executor), isEmpty);
      // Even though the price is null.
      expect(
        await (CarQuery()..where!.price.isNotIn([])).get(executor),
        hasLength(1),
      );
    });
  });

  test('a quoted name is accepted', () async {
    await insertCars(['a', 'b']);
    var cars = await (CarQuery()..orderBy('`description`', descending: true))
        .get(executor);
    expect(cars.map((c) => c.description), ['b', 'a']);
    var grouped = CarQuery()
      ..groupBy(
        '`description`, id, created_at, updated_at, make, family_friendly, recalled_at, price',
      );
    expect(await grouped.get(executor), hasLength(2));
  });

  test('a join by quoted names is accepted', () async {
    await insertCars(['a', 'b']);
    await (FruitQuery()..values.commonName = 'b').insert(executor);
    var cars =
        await (CarQuery()
              ..join('fruits', '`description`', '`common_name`', alias: '`f`'))
            .get(executor);
    expect(cars.map((c) => c.description), ['b']);
  });

  test('a self join is accepted, and joins', () async {
    await insertCars(['a']);
    var cars = await (CarQuery()..selfJoin('cars', 'id', 'id')).get(executor);
    expect(cars, hasLength(1));
  });

  test('a union loads the relations of its rows', () async {
    var tree = await (TreeQuery()..values.rings = 7).insert(executor);
    await (FruitQuery()
          ..values.treeId = int.parse(tree.value.id!)
          ..values.commonName = 'fig')
        .insert(executor);
    var trees = await (TreeQuery()..where!.rings.equals(7))
        .union(TreeQuery()..where!.rings.equals(8))
        .get(executor);
    expect(trees.single.fruits.map((f) => f.commonName), ['fig']);
  });
}
