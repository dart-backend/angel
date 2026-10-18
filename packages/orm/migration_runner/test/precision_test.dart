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

import 'common.dart';

/// A table with numeric and decimal columns.
class PricesMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('prices', (table) {
      table.serial('id').primaryKey();
      table.numeric('amount', precision: 10, scale: 2);
      table.decimal('tax', precision: 5, scale: 4);
      // Without a precision: unbounded on PostgreSQL, (17, 3) on MariaDB.
      table.numeric('rate');
      table.declareColumn(
        'fee',
        Column(
          type: ColumnType.decimal,
          precision: 8,
          scale: 1,
          isNullable: false,
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

/// Changes the precision and scale of `prices.amount` and `prices.fee`, which
/// keeps its constraints, and makes `prices.id` a `bigint`, which stays
/// `AUTO_INCREMENT` on MySQL and MariaDB.
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
      table.changeColumnType(
        'fee',
        ColumnType.decimal,
        precision: 10,
        scale: 2,
        isNullable: false,
        defaultValue: 0,
      );
      table.changeColumnType(
        'id',
        ColumnType.bigInt,
        isNullable: false,
        autoIncrement: true,
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
      table.changeColumnType(
        'fee',
        ColumnType.decimal,
        precision: 8,
        scale: 1,
        isNullable: false,
        defaultValue: 0,
      );
      table.changeColumnType(
        'id',
        ColumnType.int,
        isNullable: false,
        autoIncrement: true,
      );
    });
  }
}

void main() async {
  var skipPostgres = await skipUnlessPostgres();
  var skipMySql = await skipUnlessMySql();

  group('SQL', () {
    test('PostgreSQL', () {
      var create = PostgresSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('"amount" numeric(10, 2)'));
      expect(create.compile(), contains('"tax" decimal(5, 4)'));
      expect(
        create.compile(),
        contains('"fee" decimal(8, 1) NOT NULL DEFAULT 0'),
      );

      // The column keeps its constraints, and gets those given.
      var alter = PostgresSchema();
      AlterPricesMigration().up(alter);
      var sql = alter.compile();
      expect(sql, contains('ALTER COLUMN "amount" TYPE numeric(12, 4),'));
      expect(sql, isNot(contains('ALTER COLUMN "amount" SET')));
      expect(sql, contains('ALTER COLUMN "fee" TYPE decimal(10, 2),'));
      expect(sql, contains('ALTER COLUMN "fee" SET NOT NULL,'));
      expect(sql, contains('ALTER COLUMN "fee" SET DEFAULT 0,'));
      expect(sql, contains('ALTER COLUMN "id" TYPE bigint,'));
      expect(sql, isNot(contains('AUTO_INCREMENT')));
    });

    test('a numeric without a precision', () {
      // Unbounded on PostgreSQL, also when a column is changed to it, so
      // that its values are kept.
      var postgres = PostgresSchema();
      PricesMigration().up(postgres);
      expect(postgres.compile(), contains('"rate" numeric,'));
      postgres = PostgresSchema()
        ..alter('prices', (t) => t.changeColumnType('a', ColumnType.numeric));
      expect(postgres.compile(), contains('ALTER COLUMN "a" TYPE numeric;'));

      // MySQL and MariaDB have no unbounded numeric, and round to whole
      // numbers without a precision, so (17, 3).
      var mySql = MySqlSchema();
      PricesMigration().up(mySql);
      expect(mySql.compile(), contains('rate numeric(17, 3)'));
      var mariaDb = MariaDbSchema();
      PricesMigration().up(mariaDb);
      expect(mariaDb.compile(), contains('rate numeric(17, 3)'));
      var mysql = MySqlSchema()
        ..alter('prices', (t) => t.changeColumnType('a', ColumnType.numeric));
      expect(mysql.compile(), contains('MODIFY a numeric(17, 3)'));

      // A precision without a scale, or a scale without a precision.
      postgres = PostgresSchema()
        ..create('t', (t) {
          t.numeric('p', precision: 8);
          t.numeric('s', scale: 2);
        });
      expect(postgres.compile(), contains('"p" numeric(8),'));
      expect(postgres.compile(), contains('"s" numeric(17, 2)'));
    });

    test('rejects a precision or scale above the limits of the database', () {
      expect(
        () =>
            (MySqlSchema()
                  ..create('t', (t) => t.numeric('a', precision: 70, scale: 2)))
                .compile(),
        throwsArgumentError,
      );
      expect(
        () =>
            (MySqlSchema()..create(
                  't',
                  (t) => t.numeric('a', precision: 60, scale: 35),
                ))
                .compile(),
        throwsArgumentError,
      );
      expect(
        (MariaDbSchema()
              ..create('t', (t) => t.numeric('a', precision: 60, scale: 35)))
            .compile(),
        contains('numeric(60, 35)'),
      );
      expect(
        () =>
            (PostgresSchema()
                  ..create('t', (t) => t.numeric('a', precision: 1001)))
                .compile(),
        throwsArgumentError,
      );
    });

    test('MySQL', () {
      var create = MySqlSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('amount numeric(10, 2)'));
      expect(create.compile(), contains('tax decimal(5, 4)'));
      expect(
        create.compile(),
        contains('fee decimal(8, 1) NOT NULL DEFAULT 0'),
      );

      // MODIFY defines the whole column, with the constraints given.
      var alter = MySqlSchema();
      AlterPricesMigration().up(alter);
      var sql = alter.compile();
      expect(sql, contains('MODIFY amount numeric(12, 4),'));
      expect(sql, contains('MODIFY fee decimal(10, 2) NOT NULL DEFAULT 0,'));
      expect(sql, contains('MODIFY id bigint NOT NULL AUTO_INCREMENT'));
    });

    test('MariaDB', () {
      var create = MariaDbSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('amount numeric(10, 2)'));
      expect(create.compile(), contains('tax decimal(5, 4)'));
      expect(
        create.compile(),
        contains('fee decimal(8, 1) NOT NULL DEFAULT 0'),
      );

      // MODIFY defines the whole column, with the constraints given.
      var alter = MariaDbSchema();
      AlterPricesMigration().up(alter);
      var sql = alter.compile();
      expect(sql, contains('MODIFY amount numeric(12, 4),'));
      expect(sql, contains('MODIFY fee decimal(10, 2) NOT NULL DEFAULT 0,'));
      expect(sql, contains('MODIFY id bigint NOT NULL AUTO_INCREMENT'));
    });
  });

  group('PostgreSQL', skip: skipPostgres, () {
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
        "column_default, is_nullable FROM information_schema.columns "
        "WHERE table_schema = current_schema() AND table_name = 'prices' "
        "ORDER BY column_name",
      );
      expect(rows.map((r) => r.toList()), [
        ['amount', 'numeric', 12, 4, null, 'YES'],
        ['fee', 'numeric', 10, 2, '0', 'NO'],
        ['id', 'bigint', 64, 0, "nextval('prices_id_seq'::regclass)", 'NO'],
        ['rate', 'numeric', null, null, null, 'YES'],
        ['tax', 'numeric', 5, 4, null, 'YES'],
      ]);

      // The unbounded numeric keeps all the digits.
      await conn.execute(
        'INSERT INTO prices (amount, tax, rate) '
        'VALUES (1, 0.1, 123456789012345678.123456)',
      );
      var rate = await conn.execute('SELECT rate::text FROM prices');
      expect(rate.first.first, '123456789012345678.123456');
    });
  });

  group('MariaDB', skip: skipMySql, () {
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
        "column_default, is_nullable, extra FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'prices' "
        "ORDER BY column_name",
      );
      // `mysql1` gives `column_default` as a `Blob`, and MariaDB a column
      // without a default as `NULL`.
      expect(rows.map((r) => [...r.take(4), r[4].toString(), r[5], r[6]]), [
        ['amount', 'decimal', 12, 4, 'NULL', 'YES', ''],
        ['fee', 'decimal', 10, 2, '0.00', 'NO', ''],
        ['id', 'bigint', 19, 0, 'null', 'NO', 'auto_increment'],
        ['rate', 'decimal', 17, 3, 'NULL', 'YES', ''],
        ['tax', 'decimal', 5, 4, 'NULL', 'YES', ''],
      ]);
    });
  });
}
