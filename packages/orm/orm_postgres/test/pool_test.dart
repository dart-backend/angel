import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';

/// The queries of `angel3_orm` that return rows, run through a
/// `PostgreSqlPoolExecutor`, which ran them with a `RETURNING` too many.
void main() {
  late PostgreSqlPoolExecutor executor;

  // Each resource is released by its own tear-down, registered once it is
  // made, so that a setUp that fails part-way, or a release that fails,
  // leaves the others released.
  setUp(() async {
    var conn = await openPgConnection();
    addTearDown(conn.close);
    var runner = await createTables(conn, [CarMigration()]);
    addTearDown(() => dropTables(runner));
    var pool = Pool.withEndpoints([
      pgEndpoint(),
    ], settings: PoolSettings(sslMode: SslMode.disable));
    addTearDown(pool.close);
    executor = PostgreSqlPoolExecutor(pool);
  });

  Future<Car> insertFerrari() async {
    var now = DateTime.now();
    var insert = CarQuery()
      ..values.make = 'Ferrari'
      ..values.description = 'Vroom'
      ..values.familyFriendly = false
      ..values.recalledAt = now
      ..values.createdAt = now
      ..values.updatedAt = now;
    return (await insert.insert(executor)).value;
  }

  test('inserts, reads and updates', () async {
    var ferrari = await insertFerrari();
    expect(ferrari.id, isNotNull);
    expect(ferrari.make, 'Ferrari');

    var read = CarQuery()..where!.id.equals(ferrari.idAsInt);
    expect((await read.getOne(executor)).value.make, 'Ferrari');

    var update = CarQuery()
      ..where!.id.equals(ferrari.idAsInt)
      ..values.make = 'Mazda';
    expect((await update.update(executor)).single.make, 'Mazda');
  });

  test('deletes', () async {
    var ferrari = await insertFerrari();

    var delete = CarQuery()..where!.id.equals(ferrari.idAsInt);
    expect((await delete.delete(executor)).single.make, 'Ferrari');
    expect(await CarQuery().get(executor), isEmpty);

    var deleteOne = CarQuery()
      ..where!.id.equals((await insertFerrari()).idAsInt);
    expect((await deleteOne.deleteOne(executor)).value.make, 'Ferrari');
  });
}
