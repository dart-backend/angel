import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
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

    test('with an order and no limit returns every row in order', () async {
      var deleted = await (CarQuery()..orderBy('description', descending: true))
          .delete(executor);
      expect(deleted.map((c) => c.description), ['c', 'b', 'a']);
      expect(await descriptions(), isEmpty);
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

    test("with a ' in its key", () async {
      expect(await count((w) => w.value["it's"].asString!.equals('quoted')), 1);
      expect(await count((w) => w.value["x' OR '1'='1"].isNotNull), 0);
    });
  });
}
