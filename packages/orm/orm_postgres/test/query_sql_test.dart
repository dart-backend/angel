import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';
import 'models/has_map.dart';
import 'models/tree.dart';

/// That the SQL of a query is accepted by the database, and does what it says.
void main() {
  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      CarMigration(),
      HasMapMigration(),
      TreeMigration(),
      FruitMigration(),
    ]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) await conn.close();
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

  group('a limit on tables of the same rows', () {
    // A ctid is unique only within a table: the first row of each has one.
    setUp(() async {
      await insertCars(['parent']);
      await conn.execute('CREATE TABLE cars_child () INHERITS (cars)');
      await conn.execute(
        "INSERT INTO cars_child (make, description, family_friendly) "
        "VALUES ('x', 'child', false)",
      );
    });

    tearDown(() => conn.execute('DROP TABLE cars_child'));

    test('deletes only the rows of the limit', () async {
      var deleted =
          await (CarQuery()
                ..orderBy('description')
                ..limit(1))
              .delete(executor);
      expect(deleted.map((c) => c.description), ['child']);
      expect(await descriptions(), ['parent']);
    });

    test('updates only the rows of the limit', () async {
      var updated =
          await (CarQuery()
                ..values.make = 'y'
                ..orderBy('description')
                ..limit(1))
              .update(executor);
      expect(updated.map((c) => c.description), ['child']);
      var made = await (CarQuery()..where!.make.equals('y')).get(executor);
      expect(made.map((c) => c.description), ['child']);
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

  test('a full join returns only the rows an update wrote', () async {
    await insertCars(['a']);
    await (FruitQuery()..values.commonName = 'z').insert(executor);
    var updated =
        await (CarQuery()
              ..values.make = 'y'
              ..fullOuterJoin(
                'fruits',
                'description',
                'common_name',
                additionalFields: const ['common_name'],
              ))
            .update(executor);
    expect(updated.map((c) => c.description), ['a']);
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

  test('a read of a delete locks only its own table', () async {
    await insertCars(['a']);
    await (FruitQuery()..values.commonName = 'a').insert(executor);
    var deleted =
        await (CarQuery()..leftJoin('fruits', 'description', 'common_name'))
            .delete(executor);
    expect(deleted, hasLength(1));
  });

  test(
    'two connections deleting rows with relations return different rows',
    () async {
      var other = await openPgConnection();
      addTearDown(other.close);
      var otherExecutor = await createExecutor(other);
      for (var rings in [1, 2]) {
        await (TreeQuery()..values.rings = rings).insert(executor);
      }
      TreeQuery next() => TreeQuery()
        ..orderBy('rings')
        ..limit(1);
      var claimed = await Future.wait([
        next().delete(executor),
        next().delete(otherExecutor),
      ]);
      var rings = [for (var trees in claimed) ...trees.map((t) => t.rings)];
      // The second reads the first's row after it was deleted, so it finds
      // another or none: never the same one.
      expect(rings.toSet(), hasLength(rings.length));
    },
  );

  test('a join with a column named as the table keeps a row of NULL', () async {
    await conn.execute('CREATE TABLE car_notes (cars text, common_name text)');
    addTearDown(() => conn.execute('DROP TABLE car_notes'));
    await conn.execute("INSERT INTO car_notes (common_name) VALUES ('a')");
    await insertCars(['a']);
    var updated =
        await (CarQuery()
              ..values.make = 'y'
              ..rightJoin('car_notes', 'description', 'common_name'))
            .update(executor);
    expect(updated.map((c) => c.description), ['a']);
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
    var cars = await (CarQuery()..orderBy('"description"', descending: true))
        .get(executor);
    expect(cars.map((c) => c.description), ['b', 'a']);
    var grouped = CarQuery()
      ..groupBy(
        '"description", id, created_at, updated_at, make, family_friendly, recalled_at, price',
      );
    expect(await grouped.get(executor), hasLength(2));
  });

  group('a value a query no longer uses', () {
    setUp(() => insertCars(['a']));

    // The first predicate binds a value, which the second replaces.
    CarQuery stale() => CarQuery()
      ..where!.make.equals('x')
      ..where!.make.isIn([]);

    test('is left out of a get', () async {
      expect(await stale().get(executor), isEmpty);
    });

    test('is left out of a delete', () async {
      expect(await stale().delete(executor), isEmpty);
      expect(await descriptions(), ['a']);
    });

    test('is left out of an update', () async {
      var query = stale()..values.description = 'b';
      expect(await query.update(executor), isEmpty);
      expect(await descriptions(), ['a']);
    });

    test('on a pool too', () async {
      var pool = Pool.withEndpoints([
        pgEndpoint(),
      ], settings: PoolSettings(sslMode: SslMode.disable));
      addTearDown(pool.close);
      var poolExecutor = PostgreSqlPoolExecutor(pool);
      expect(await stale().get(poolExecutor), isEmpty);
    });
  });

  test('a join by quoted names is accepted', () async {
    await insertCars(['a', 'b']);
    await (FruitQuery()..values.commonName = 'b').insert(executor);
    var cars =
        await (CarQuery()
              ..join('fruits', '"description"', '"common_name"', alias: '"f"'))
            .get(executor);
    expect(cars.map((c) => c.description), ['b']);
  });

  group('values, as the driver reads the SQL', () {
    setUp(() => insertCars(['a']));

    // `make` is bound to `x`, so each matches the one car.
    Future<void> expectMatch(String raw) async {
      var query = CarQuery();
      query.substitutionValues['m'] = 'x';
      query.where!.raw(raw);
      expect(await query.get(executor), hasLength(1), reason: raw);
    }

    test('after a dollar-quoted string with a quote', () async {
      // A later quote, which reading `'` as opening a string would pair it with.
      await expectMatch(
        r"description <> $$it's$$ AND make = @m AND description <> 'b'",
      );
    });

    test('after a comment with a quote', () async {
      await expectMatch(
        "description <> 'b' -- don't\n AND make = @m AND description <> 'c'",
      );
      await expectMatch(
        "description <> 'b' /* don't */ AND make = @m AND description <> 'c'",
      );
    });

    test('after a string that ends in a backslash', () async {
      await expectMatch(
        r"description <> 'b\' AND make = @m AND description <> 'c'",
      );
    });

    test('left out when only a comment names them', () async {
      var query = CarQuery();
      query.substitutionValues['m'] = 'x';
      query.where!.raw("make = 'x' /* @m */");
      expect(await query.get(executor), hasLength(1));
    });

    test('left out in a transaction, which goes on', () async {
      var cars = await executor.transaction((tx) async {
        var stale = CarQuery()
          ..where!.make.equals('x')
          ..where!.make.isIn([]);
        expect(await stale.get(tx), isEmpty);
        return CarQuery().get(tx);
      });
      expect(cars, hasLength(1));
    });

    test('a value that is missing is still an error', () async {
      var query = CarQuery()..where!.raw('make = @nothing');
      expect(query.get(executor), throwsArgumentError);
    });
  });

  group('a union of a value it cannot rename', () {
    setUp(() => insertCars(['a']));

    test('is an error, not the value of its left query', () async {
      var left = CarQuery()..where!.make.equals('x');
      var right = CarQuery();
      right.substitutionValues['make'] = 'none';
      right.where!.raw(
        r"description <> $$it's$$ AND make = @make AND description <> 'b'",
      );
      expect(left.unionAll(right).get(executor), throwsStateError);
    });

    test('runs with a value of another name', () async {
      var left = CarQuery()..where!.make.equals('x');
      var right = CarQuery();
      right.substitutionValues['right_make'] = 'none';
      right.where!.raw(
        r"description <> $$it's$$ AND make = @right_make AND description <> 'b'",
      );
      var cars = await left.unionAll(right).get(executor);
      expect(cars, hasLength(1));
    });
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

  group('a JSON property', () {
    setUp(() async {
      await (HasMapQuery()
            ..values.value = {
              'n': 10,
              'text': 'x',
              'at': '2020-06-01T00:00:00Z',
              'nested': {'k': 'v', 'n': 1},
              "it's": 'quoted',
            }
            ..values.list = ['1', 2, 3.5])
          .insert(executor);
    });

    Future<int> count(void Function(HasMapQueryWhere) where) async {
      var query = HasMapQuery();
      where(query.where!);
      return (await query.get(executor)).length;
    }

    test('as a number is compared as one, not as text', () async {
      expect(await count((w) => w.value['n'].asInt!.greaterThan(5)), 1);
      expect(await count((w) => w.value['n'].asInt!.lessThan(5)), 0);
      expect(await count((w) => w.value['n'].asInt!.equals(10)), 1);
      expect(await count((w) => w.list[2].asDouble!.equals(3.5)), 1);
    });

    test('as a number supports isBetween and isIn', () async {
      expect(await count((w) => w.value['n'].asInt!.isBetween(5, 15)), 1);
      expect(await count((w) => w.value['n'].asInt!.isBetween(1, 5)), 0);
      expect(await count((w) => w.value['n'].asInt!.isIn([9, 10])), 1);
      expect(await count((w) => w.value['n'].asInt!.isNotIn([10])), 0);
    });

    test('that is no number matches no comparison, without an error', () async {
      expect(await count((w) => w.value['text'].asInt!.greaterThan(0)), 0);
      expect(await count((w) => w.list[0].asInt!.equals(1)), 0);
    });

    test('as a string', () async {
      expect(await count((w) => w.value['text'].asString!.equals('x')), 1);
      expect(await count((w) => w.value['text'].asString!.isIn(['x', 'y'])), 1);
    });

    test('as a date is compared as one', () async {
      expect(
        await count(
          (w) => w.value['at'].asDateTime!.greaterThan(DateTime.utc(2020)),
        ),
        1,
      );
      expect(
        await count(
          (w) => w.value['at'].asDateTime!.lessThan(DateTime.utc(2020)),
        ),
        0,
      );
      expect(
        await count((w) => w.value['at'].asDateTime!.year.equals(2020)),
        1,
      );
    });

    test('as a map', () async {
      expect(
        await count((w) => w.value['nested'].asMap!.contains({'k': 'v'})),
        1,
      );
      expect(
        await count((w) => w.value['nested'].asMap!.contains({'k': 'z'})),
        0,
      );
      expect(
        await count((w) => w.value['nested'].asMap!['n'].asInt!.equals(1)),
        1,
      );
    });

    test('with a backslash in its key', () async {
      await (HasMapQuery()
            ..values.value = {r'a\': 'x', 'b': 'y'}
            ..values.list = [])
          .insert(executor);
      expect(await count((w) => w.value[r'a\'].asString!.equals('x')), 1);
      expect(await count((w) => w.value[r'a\'].asString!.equals('z')), 0);
      expect(
        await count((w) {
          w.value[r'a\'].asString!.equals('x');
          w.value['b'].asString!.equals('y');
        }),
        1,
      );
    });

    test(
      'with a backslash in its key, in a union, binds its own value',
      () async {
        await (HasMapQuery()
              ..values.value = {r'a\': 'x', 'b': 'y'}
              ..values.list = [])
            .insert(executor);
        var left = HasMapQuery()..where!.value['b'].asString!.equals('none');
        var right = HasMapQuery();
        right.where!.value[r'a\'].asString!.equals('x');
        right.where!.value['b'].asString!.equals('y');
        expect(await left.unionAll(right).get(executor), hasLength(1));
      },
    );

    test('with a backslash in its key, in an insert', () async {
      var query = HasMapQuery()
        ..where!.value[r'a\'].asString!.equals('x')
        ..where!.value['b'].asString!.equals('y')
        ..values.value = {'c': 1}
        ..values.list = [];
      expect((await query.insert(executor)).isPresent, isTrue);
    });

    group('of a value it cannot be read as', () {
      setUp(() async {
        await (HasMapQuery()
              ..values.value = {'at': 'soon', 'nested': 'no json', 'none': null}
              ..values.list = [])
            .insert(executor);
      });

      test('as a date matches no comparison, without an error', () async {
        // The row of the setUp of the group above still matches.
        expect(
          await count(
            (w) => w.value['at'].asDateTime!.greaterThan(DateTime.utc(2020)),
          ),
          1,
        );
        expect(
          await count((w) => w.value['at'].asDateTime!.year.equals(2020)),
          1,
        );
        expect(
          await count(
            (w) => w.value['text'].asDateTime!.greaterThan(DateTime.utc(2020)),
          ),
          0,
        );
      });

      test('as a date, of a number, matches no comparison', () async {
        expect(
          await count(
            (w) => w.value['n'].asDateTime!.greaterThan(DateTime.utc(2020)),
          ),
          0,
        );
      });

      test('as a map matches nothing, without an error', () async {
        expect(
          await count((w) => w.value['nested'].asMap!.contains({'k': 'v'})),
          1,
        );
        expect(
          await count(
            (w) => w.value['nested'].asMap!['k'].asString!.equals('v'),
          ),
          1,
        );
      });

      test('of another type is not null', () async {
        expect(await count((w) => w.value['nested'].asInt!.isNotNull), 2);
        expect(await count((w) => w.value['nested'].asInt!.isNull), 0);
        expect(await count((w) => w.value['at'].asDateTime!.isNotNull), 2);
        expect(await count((w) => w.value['at'].asDateTime!.isNull), 0);
        expect(await count((w) => w.value['none'].asInt!.isNull), 2);
      });

      test('as a map is null for a JSON null, as for a missing key', () async {
        expect(await count((w) => w.value['none'].asMap!.isNull), 2);
        expect(await count((w) => w.value['missing'].asMap!.isNull), 2);
        expect(await count((w) => w.value['nested'].asMap!.isNotNull), 2);
      });
    });

    test("with a ' in its key", () async {
      expect(await count((w) => w.value["it's"].asString!.equals('quoted')), 1);
      expect(await count((w) => w.value["x' OR '1'='1"].isNotNull), 0);
    });
  });
}
