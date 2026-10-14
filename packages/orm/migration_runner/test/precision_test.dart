import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql1/mysql1.dart' as mysql1;
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

/// A table with numeric and decimal columns.
class PricesMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('prices', (table) {
      table.serial('id').primaryKey();
      table.numeric('amount', precision: 10, scale: 2);
      table.decimal('tax', precision: 5, scale: 4);
      table.declareColumn(
        'fee',
        Column(
          type: ColumnType.decimal,
          precision: 8,
          scale: 1,
          defaultValue: 0,
        ),
      );
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('prices');
  }
}

/// Changes the precision and scale of `prices.amount`.
class AlterPricesMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.alter('prices', (table) {
      table.changeColumnType(
        'amount',
        ColumnType.numeric,
        precision: 12,
        scale: 4,
      );
    });
  }

  @override
  void down(Schema schema) {
    schema.alter('prices', (table) {
      table.changeColumnType(
        'amount',
        ColumnType.numeric,
        precision: 10,
        scale: 2,
      );
    });
  }
}

void main() {
  group('SQL', () {
    test('PostgreSQL', () {
      var create = PostgresSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('"amount" numeric(10, 2)'));
      expect(create.compile(), contains('"tax" decimal(5, 4)'));
      expect(create.compile(), contains('"fee" decimal(8, 1) DEFAULT 0'));

      var alter = PostgresSchema();
      AlterPricesMigration().up(alter);
      expect(
        alter.compile(),
        contains('ALTER COLUMN "amount" TYPE numeric(12, 4)'),
      );
    });

    test('MySQL', () {
      var create = MySqlSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('amount numeric(10, 2)'));
      expect(create.compile(), contains('tax decimal(5, 4)'));
      expect(create.compile(), contains('fee decimal(8, 1) DEFAULT 0'));

      var alter = MySqlSchema();
      AlterPricesMigration().up(alter);
      expect(alter.compile(), contains('MODIFY amount numeric(12, 4)'));
    });

    test('MariaDB', () {
      var create = MariaDbSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('amount numeric(10, 2)'));
      expect(create.compile(), contains('tax decimal(5, 4)'));
      expect(create.compile(), contains('fee decimal(8, 1) DEFAULT 0'));

      var alter = MariaDbSchema();
      AlterPricesMigration().up(alter);
      expect(alter.compile(), contains('MODIFY amount numeric(12, 4)'));
    });
  });

  group('PostgreSQL', () {
    late Connection conn;
    late MigrationRunner runner;

    setUp(() async {
      conn = await Connection.open(
        Endpoint(
          host: Platform.environment['POSTGRES_HOST'] ?? 'localhost',
          database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
          username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
          password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123',
        ),
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
      runner = PostgresMigrationRunner(
        conn,
        migrations: [PricesMigration(), AlterPricesMigration()],
      );
    });

    tearDown(() async {
      await runner.reset();
      await conn.close();
    });

    test('creates and alters the columns', () async {
      await runner.up();

      var rows = await conn.execute(
        "SELECT column_name, data_type, numeric_precision, numeric_scale, "
        "column_default FROM information_schema.columns "
        "WHERE table_schema = current_schema() AND table_name = 'prices' "
        "AND column_name <> 'id' ORDER BY column_name",
      );
      expect(rows.map((r) => r.toList()), [
        ['amount', 'numeric', 12, 4, null],
        ['fee', 'numeric', 8, 1, '0'],
        ['tax', 'numeric', 5, 4, null],
      ]);
    });
  });

  group('MariaDB', () {
    late mysql1.MySqlConnection conn;
    late MigrationRunner runner;

    setUp(() async {
      conn = await mysql1.MySqlConnection.connect(
        mysql1.ConnectionSettings(
          host: Platform.environment['MYSQL_HOST'] ?? 'localhost',
          port: 3306,
          db: Platform.environment['MYSQL_DB'] ?? 'orm_test',
          user: Platform.environment['MYSQL_USERNAME'] ?? 'test',
          password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123',
        ),
      );
      runner = MariaDbMigrationRunner(
        conn,
        migrations: [PricesMigration(), AlterPricesMigration()],
      );
    });

    tearDown(() async {
      await runner.reset();
      await conn.close();
    });

    test('creates and alters the columns', () async {
      await runner.up();

      var rows = await conn.query(
        "SELECT column_name, data_type, numeric_precision, numeric_scale, "
        "column_default FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'prices' "
        "AND column_name <> 'id' ORDER BY column_name",
      );
      // `mysql1` gives `column_default` as a `Blob`, and MariaDB a column
      // without a default as `NULL`.
      expect(rows.map((r) => [...r.take(4), r[4].toString()]), [
        ['amount', 'decimal', 12, 4, 'NULL'],
        ['fee', 'decimal', 8, 1, '0.0'],
        ['tax', 'decimal', 5, 4, 'NULL'],
      ]);
    });
  });
}
