import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';

// Run with a `TZ` other than UTC, such as `TZ=Asia/Kuala_Lumpur`, as CI does:
// at UTC a local DateTime is the same as a UTC one, so the tests are skipped.
void main() {
  if (DateTime.now().timeZoneOffset == Duration.zero) {
    test(
      'time zones',
      () {},
      skip: 'The local time zone is UTC. Run with TZ=Asia/Kuala_Lumpur.',
    );
    return;
  }

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

  Future<Car> insert(DateTime recalledAt) async {
    var query = CarQuery()
      ..values.make = 'Ferrari'
      ..values.description = 'Vroom'
      ..values.familyFriendly = false
      ..values.recalledAt = recalledAt
      ..values.price = 1;
    return (await query.insert(executor)).value;
  }

  test('a local DateTime is read back as the same moment', () async {
    var local = DateTime(2026, 10, 31, 10, 30);
    var car = await insert(local);
    expect(car.recalledAt!.isAtSameMomentAs(local), isTrue);

    var read = (await CarQuery().getOne(executor)).value;
    expect(read.recalledAt!.isAtSameMomentAs(local), isTrue);
  });

  test('a UTC DateTime is read back as the same moment', () async {
    var utc = DateTime.utc(2026, 10, 31, 10, 30);
    var car = await insert(utc);
    expect(car.recalledAt, utc);
  });

  test('a where clause on a local DateTime matches the row', () async {
    var local = DateTime(2026, 10, 31, 10, 30);
    await insert(local);

    Future<int> count(void Function(CarQueryWhere where) f) async {
      var query = CarQuery();
      f(query.where!);
      return (await query.get(executor)).length;
    }

    expect(await count((w) => w.recalledAt.equals(local)), 1);
    expect(await count((w) => w.recalledAt.equals(local.toUtc())), 1);
    expect(
      await count(
        (w) => w.recalledAt.lessThan(local.add(const Duration(minutes: 1))),
      ),
      1,
    );
    expect(
      await count(
        (w) => w.recalledAt.greaterThan(local.add(const Duration(minutes: 1))),
      ),
      0,
    );
    expect(
      await count(
        (w) => w.recalledAt.isBetween(
          local.subtract(const Duration(hours: 1)),
          local.add(const Duration(hours: 1)),
        ),
      ),
      1,
    );
    expect(await count((w) => w.recalledAt.isIn([local])), 1);
  });
}
