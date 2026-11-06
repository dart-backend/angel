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
