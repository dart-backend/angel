import 'dart:io';

import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/car.dart';

void main() {
  late Connection conn;
  late MigrationRunner runner;
  late Pool pool;
  late PostgreSqlPoolExecutor executor;

  setUp(() async {
    conn = await openPgConnection();
    runner = await createTables(conn, [CarMigration()]);
    pool = Pool.withEndpoints([
      Endpoint(
        host: Platform.environment['POSTGRES_HOSTNAME'] ?? 'localhost',
        port: int.parse(Platform.environment['POSTGRES_PORT'] ?? '5432'),
        database: Platform.environment['POSTGRES_DB'] ?? 'postgres',
        username: Platform.environment['POSTGRES_USERNAME'] ?? 'postgres',
        password: Platform.environment['POSTGRES_PASSWORD'] ?? 'postgres',
      ),
    ], settings: PoolSettings(sslMode: SslMode.disable));
    executor = PostgreSqlPoolExecutor(pool);
  });

  tearDown(() async {
    await pool.close();
    await dropTables(runner);
    await conn.close();
  });

  test('inserts, reads and updates through the pool', () async {
    var now = DateTime.now();
    var insert = CarQuery()
      ..values.make = 'Ferrari'
      ..values.description = 'Vroom'
      ..values.familyFriendly = false
      ..values.recalledAt = now
      ..values.createdAt = now
      ..values.updatedAt = now;
    var ferrari = (await insert.insert(executor)).value;
    expect(ferrari.id, isNotNull);
    expect(ferrari.make, 'Ferrari');

    var read = CarQuery()..where!.id.equals(ferrari.idAsInt);
    expect((await read.getOne(executor)).value.make, 'Ferrari');

    var update = CarQuery()
      ..where!.id.equals(ferrari.idAsInt)
      ..values.make = 'Mazda';
    expect((await update.update(executor)).single.make, 'Mazda');
  });
}
