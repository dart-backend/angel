import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql1/mysql1.dart' as mysql1;
import 'package:mysql_client/mysql_client.dart' as mysql_client;
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'package:angel3_migration_runner/src/change_column.dart';
import 'package:angel3_migration_runner/src/sql.dart';

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
      // A string default with a quote, which must be escaped.
      table.varChar('note', length: 20).defaultsTo("it's");
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

/// Changes the precision and scale of `prices.amount` and `prices.fee`, the
/// length of `prices.note`, and makes `prices.id` a `bigint`. Going up, the
/// constraints are not given, so that `fee` keeps its `NOT NULL DEFAULT 0`,
/// `note` its default and `id` its `AUTO_INCREMENT`, which MySQL and MariaDB
/// read from the database. Going down, they are given.
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
      );
      table.changeColumnType('note', ColumnType.varChar, length: 30);
      table.changeColumnType('id', ColumnType.bigInt);
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
        'note',
        ColumnType.varChar,
        length: 20,
        defaultValue: "it's",
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

/// Creates a table, and changes the type of a column of it, whose
/// constraints are read once the table is created.
class CreateAndChangeMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('created', (table) {
      table.declareColumn(
        'a',
        Column(type: ColumnType.int, isNullable: false, defaultValue: 5),
      );
      // A `;` in a string does not end the statement.
      table.varChar('note', length: 20).defaultsTo("x; 'y'");
    });
    // Statements run before the constraints are read, in one text.
    schema.alter('created', (table) => table.renameColumn('a', 'c'));
    schema.alter(
      'created',
      (table) => table.changeColumnType('c', ColumnType.bigInt),
    );
    schema.indexes(
      'created',
      (indexes) =>
          indexes.addIndex('created_c', ['c'], IndexType.standardIndex),
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('created');
  }
}

/// Fails on the database.
class FailingMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.drop('no_such_table');
  }

  @override
  void down(Schema schema) {}
}

void main() async {
  group('existing constraints', () {
    test('of MariaDB, which gives defaults as SQL', () {
      var e = ExistingConstraints.parse(
        isNullable: 'NO',
        columnDefault: "'it''s'",
        extra: 'on update current_timestamp()',
        version: '11.4.2-MariaDB',
      );
      expect(e.isNullable, isFalse);
      expect((e.defaultValue as RawSql).value, "'it''s'");
      expect(e.onUpdate, 'current_timestamp()');
      expect(e.autoIncrement, isFalse);

      // `NULL` is no default.
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'NULL',
        extra: 'auto_increment',
        version: '11.4.2-MariaDB',
      );
      expect(e.defaultValue, isNull);
      expect(e.autoIncrement, isTrue);
    });

    test('of MySQL, which gives literals as their values', () {
      var e = ExistingConstraints.parse(
        isNullable: 'NO',
        columnDefault: "it's",
        extra: '',
        version: '8.4.0',
      );
      expect(e.defaultValue, "it's");

      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'CURRENT_TIMESTAMP',
        extra: 'DEFAULT_GENERATED on update CURRENT_TIMESTAMP',
        version: '8.4.0',
      );
      expect((e.defaultValue as RawSql).value, 'CURRENT_TIMESTAMP');
      expect(e.onUpdate, 'CURRENT_TIMESTAMP');

      // Other expressions in parentheses.
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'rand()',
        extra: 'DEFAULT_GENERATED',
        version: '8.4.0',
      );
      expect((e.defaultValue as RawSql).value, '(rand())');

      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: null,
        extra: '',
        version: '8.4.0',
      );
      expect(e.defaultValue, isNull);
    });

    test('are kept by MODIFY where not given', () {
      var modification =
          ColumnModification('at', ColumnType.dateTime, length: 255)
            ..existing = ExistingConstraints(
              isNullable: false,
              defaultValue: RawSql('CURRENT_TIMESTAMP'),
              autoIncrement: false,
              onUpdate: 'CURRENT_TIMESTAMP',
            );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        'MODIFY `at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP '
        'ON UPDATE CURRENT_TIMESTAMP',
      );

      // Those given win.
      modification =
          ColumnModification(
              'n',
              ColumnType.int,
              length: 255,
              isNullable: true,
              defaultValue: 1,
              autoIncrement: false,
            )
            ..existing = ExistingConstraints(
              isNullable: false,
              defaultValue: RawSql('0'),
              autoIncrement: true,
            );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        'MODIFY `n` int DEFAULT 1',
      );
    });

    test('are not kept by MODIFY for a type that cannot have them', () {
      var updated = ExistingConstraints(
        isNullable: false,
        defaultValue: RawSql('CURRENT_TIMESTAMP'),
        onUpdate: 'CURRENT_TIMESTAMP',
      );
      expect(
        (ColumnModification(
          'at',
          ColumnType.varChar,
          length: 20,
        )..existing = updated).compile(MySqlGenerator.compileColumn),
        'MODIFY `at` varchar(20) NOT NULL',
      );
      expect(
        (ColumnModification(
          'at',
          ColumnType.timeStamp,
          length: 20,
        )..existing = updated).compile(MySqlGenerator.compileColumn),
        'MODIFY `at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP '
        'ON UPDATE CURRENT_TIMESTAMP',
      );

      var counter = ExistingConstraints(isNullable: false, autoIncrement: true);
      expect(
        (ColumnModification(
          'id',
          ColumnType.decimal,
          length: 255,
        )..existing = counter).compile(MySqlGenerator.compileColumn),
        'MODIFY `id` decimal(17, 3) NOT NULL',
      );
      expect(
        (ColumnModification(
          'id',
          ColumnType.bigInt,
          length: 255,
        )..existing = counter).compile(MySqlGenerator.compileColumn),
        'MODIFY `id` bigint NOT NULL AUTO_INCREMENT',
      );
      // Unless given.
      expect(
        (ColumnModification(
          'id',
          ColumnType.decimal,
          length: 255,
          autoIncrement: true,
        )..existing = counter).compile(MySqlGenerator.compileColumn),
        'MODIFY `id` decimal(17, 3) NOT NULL AUTO_INCREMENT',
      );
    });

    test('of generated and unsigned columns', () {
      var e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: null,
        extra: 'STORED GENERATED',
        version: '8.4.0',
        columnType: 'int unsigned',
        generationExpression: r"concat(`a`,_utf8mb4\'x\')",
      );
      expect(e.unsigned, isTrue);
      expect(e.generationExpression, "concat(`a`,_utf8mb4'x')");
      expect(e.stored, isTrue);

      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'NULL',
        extra: 'VIRTUAL GENERATED',
        version: '11.4.2-MariaDB',
        columnType: 'int(11)',
        generationExpression: '`a` + 1',
      );
      expect(e.unsigned, isFalse);
      expect(e.generationExpression, '`a` + 1');
      expect(e.stored, isFalse);

      // DEFAULT_GENERATED is a default, not a generated column.
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'rand()',
        extra: 'DEFAULT_GENERATED',
        version: '8.4.0',
        generationExpression: '',
      );
      expect(e.generationExpression, isNull);
    });

    test('are kept by MODIFY: UNSIGNED and generation', () {
      var modification = ColumnModification('n', ColumnType.bigInt, length: 255)
        ..existing = ExistingConstraints(
          isNullable: false,
          columnType: 'int unsigned',
        );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        'MODIFY `n` bigint unsigned NOT NULL',
      );
      // Not for a type that cannot be.
      modification = ColumnModification('n', ColumnType.varChar, length: 9)
        ..existing = ExistingConstraints(
          isNullable: true,
          columnType: 'int unsigned',
        );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        'MODIFY `n` varchar(9)',
      );

      modification =
          ColumnModification(
              'g',
              ColumnType.decimal,
              length: 255,
              precision: 10,
              scale: 2,
              isNullable: false,
            )
            ..existing = ExistingConstraints(
              isNullable: true,
              columnType: 'int',
              generationExpression: '`a` * 2',
              stored: true,
            );
      expect(
        modification.compile(MariaDbGenerator.compileColumn),
        'MODIFY `g` decimal(10, 2) GENERATED ALWAYS AS (`a` * 2) STORED '
        'NOT NULL',
      );
    });

    test('of MySQL 8 expressions, whose quotes it escapes', () {
      var e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: r"concat(_utf8mb4\'a\',_utf8mb4\'b\\c\')",
        extra: 'DEFAULT_GENERATED',
        dataType: 'varchar',
        version: '8.4.0',
      );
      expect(
        (e.defaultValue as RawSql).value,
        r"(concat(_utf8mb4'a',_utf8mb4'b\c'))",
      );
    });

    test('of older servers, without DEFAULT_GENERATED', () {
      // MySQL before 8.0.13.
      var e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'CURRENT_TIMESTAMP',
        extra: 'on update CURRENT_TIMESTAMP',
        dataType: 'timestamp',
        version: '5.7.44-log',
      );
      expect((e.defaultValue as RawSql).value, 'CURRENT_TIMESTAMP');

      // MariaDB before 10.2.7, which gives literals as their values.
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'current_timestamp()',
        extra: '',
        dataType: 'datetime',
        version: '5.5.5-10.1.48-MariaDB',
      );
      expect((e.defaultValue as RawSql).value, 'current_timestamp()');
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: "it's",
        extra: '',
        dataType: 'varchar',
        version: '10.1.48-MariaDB',
      );
      expect(e.defaultValue, "it's");

      // The text of the current time, of a string, is a literal.
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: 'CURRENT_TIMESTAMP',
        extra: '',
        dataType: 'varchar',
        version: '5.7.44',
      );
      expect(e.defaultValue, 'CURRENT_TIMESTAMP');

      // A bit is SQL.
      e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: "b'1'",
        extra: '',
        dataType: 'bit',
        version: '8.4.0',
      );
      expect((e.defaultValue as RawSql).value, "b'1'");
    });
  });

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
      expect(sql, contains('ALTER COLUMN "id" TYPE bigint;'));
      expect(sql, isNot(contains('SET NOT NULL')));
      expect(sql, isNot(contains('DEFAULT')));

      // Going down, the constraints given are set.
      var down = PostgresSchema();
      AlterPricesMigration().down(down);
      sql = down.compile();
      expect(sql, contains('ALTER COLUMN "fee" SET NOT NULL,'));
      expect(sql, contains('ALTER COLUMN "fee" SET DEFAULT 0,'));
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
      expect(mySql.compile(), contains('`rate` numeric(17, 3)'));
      var mariaDb = MariaDbSchema();
      PricesMigration().up(mariaDb);
      expect(mariaDb.compile(), contains('`rate` numeric(17, 3)'));
      var mysql = MySqlSchema()
        ..alter('prices', (t) => t.changeColumnType('a', ColumnType.numeric));
      expect(mysql.compile(), contains('MODIFY `a` numeric(17, 3)'));

      // A precision without a scale, or a scale without a precision.
      postgres = PostgresSchema()
        ..create('t', (t) {
          t.numeric('p', precision: 8);
          t.numeric('s', scale: 2);
        });
      // A precision without a scale has the default scale, not 0, which
      // would round the values to whole numbers.
      expect(postgres.compile(), contains('"p" numeric(8, 3),'));
      expect(postgres.compile(), contains('"s" numeric(17, 2)'));
    });

    test('string defaults are quoted and escaped', () {
      void change(MutableTable t) {
        t.changeColumnType('code', ColumnType.char, defaultValue: r"a'b\c");
      }

      // A quote doubled, and on MySQL and MariaDB, where it is an escape, a
      // backslash too, for every string type.
      expect(
        (MySqlSchema()..alter('t', change)).compile(),
        contains(r"MODIFY `code` char(255) DEFAULT 'a''b\\c'"),
      );
      expect(
        (MariaDbSchema()..alter('t', change)).compile(),
        contains(r"MODIFY `code` char(255) DEFAULT 'a''b\\c'"),
      );
      expect(
        (PostgresSchema()..alter('t', change)).compile(),
        contains(r"""ALTER COLUMN "code" SET DEFAULT 'a''b\c'"""),
      );
      expect(
        (MariaDbSchema()
              ..create('t', (t) => t.varChar('s').defaultsTo('active')))
            .compile(),
        contains("`s` varchar(255) DEFAULT 'active'"),
      );
      // RawSql as it is.
      expect(
        (MySqlSchema()..alter(
              't',
              (t) => t.changeColumnType(
                'at',
                ColumnType.dateTime,
                defaultValue: RawSql('CURRENT_TIMESTAMP'),
              ),
            ))
            .compile(),
        contains('MODIFY `at` datetime DEFAULT CURRENT_TIMESTAMP'),
      );
    });

    test('USING converts the values on PostgreSQL', () {
      void change(MutableTable t) => t.changeColumnType(
        'price',
        ColumnType.numeric,
        precision: 10,
        scale: 2,
        using: 'price::numeric',
      );

      expect(
        (PostgresSchema()..alter('t', change)).compile(),
        contains(
          'ALTER COLUMN "price" TYPE numeric(10, 2) USING price::numeric',
        ),
      );
      // MODIFY converts the values itself.
      expect(
        (MySqlSchema()..alter('t', change)).compile(),
        isNot(contains('USING')),
      );
    });

    test('quotes the column of MODIFY', () {
      expect(
        (MySqlSchema()
              ..alter('t', (t) => t.changeColumnType('order', ColumnType.int)))
            .compile(),
        contains('MODIFY `order` int'),
      );
    });

    test(
      'PostgreSQL drops a default before the type it may not be cast to',
      () {
        var sql =
            (PostgresSchema()..alter(
                  't',
                  (t) =>
                      t.changeColumnType('x', ColumnType.int, defaultValue: 0),
                ))
                .compile();
        expect(
          sql,
          contains(
            'ALTER COLUMN "x" DROP DEFAULT,\n'
            '  ALTER COLUMN "x" TYPE int,\n'
            '  ALTER COLUMN "x" SET DEFAULT 0;',
          ),
        );
      },
    );

    test('rejects a precision above the limits when it is declared', () {
      // Before the schema is compiled or run.
      for (var schema in <Schema>[MySqlSchema(), MariaDbSchema()]) {
        expect(
          () => schema.alter(
            't',
            (t) => t.changeColumnType('a', ColumnType.decimal, precision: 70),
          ),
          throwsArgumentError,
        );
        expect(
          () => schema.alter(
            't',
            (t) => t.declareColumn(
              'b',
              Column(type: ColumnType.decimal, precision: 70),
            ),
          ),
          throwsArgumentError,
        );
      }
    });

    test('quotes a column of MODIFY once', () {
      expect(quoteMySqlIdentifier('order'), '`order`');
      expect(quoteMySqlIdentifier('`order`'), '`order`');
      expect(quoteMySqlIdentifier('a`b'), '`a``b`');
      expect(quoteMySqlIdentifier('`a``b`'), '`a``b`');
      expect(
        (MySqlSchema()..alter(
              't',
              (t) => t.changeColumnType('`order`', ColumnType.bigInt),
            ))
            .compile(),
        contains('MODIFY `order` bigint;'),
      );
      // And reads the constraints of the column without its quotes.
      expect(
        existingConstraintsQuery('t', ['`order`']),
        endsWith("column_name IN ('order')"),
      );
    });

    test('sets and drops NOT NULL on MySQL and MariaDB with MODIFY', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.alter('t', (t) {
          t.setNotNull('a');
          t.dropNotNull('b');
        });
        var sql = schema.compile();
        // Without the database, the type is not known.
        expect(sql, contains('MODIFY `a` /* the type of `a` */ NOT NULL,'));
        expect(sql, contains('MODIFY `b` /* the type of `b` */;'));
        expect(sql, isNot(contains('ALTER COLUMN')));
      }

      // With it, the column keeps its type and its other constraints.
      var modification = ColumnModification.nullability('a', isNullable: false)
        ..existing = ExistingConstraints(
          isNullable: true,
          defaultValue: '3',
          autoIncrement: true,
          columnType: 'int(10) unsigned',
        );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        "MODIFY `a` int(10) unsigned NOT NULL DEFAULT '3' AUTO_INCREMENT",
      );
    });

    test('a serial type is its integer on MySQL and MariaDB', () {
      for (var (serial, integer) in [
        (ColumnType.smallSerial, 'smallint'),
        (ColumnType.serial, 'int'),
        (ColumnType.bigSerial, 'bigint'),
      ]) {
        for (var compileColumn in [
          MySqlGenerator.compileColumn,
          MariaDbGenerator.compileColumn,
        ]) {
          // With AUTO_INCREMENT, unless it is not given.
          expect(
            ColumnModification(
              'id',
              serial,
              length: 255,
            ).compile(compileColumn),
            'MODIFY `id` $integer AUTO_INCREMENT',
          );
          expect(
            ColumnModification(
              'id',
              serial,
              length: 255,
              autoIncrement: false,
            ).compile(compileColumn),
            'MODIFY `id` $integer',
          );
          expect(
            compileColumn(MigrationColumn(serial)..primaryKey()),
            '$integer PRIMARY KEY NOT NULL AUTO_INCREMENT',
          );
        }
      }
    });

    test('quotes the columns of every MySQL and MariaDB clause', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema
          ..create('t', (t) => t.integer('order'))
          ..alter('t', (t) {
            t.renameColumn('order', 'key');
            t.dropColumn('`desc`');
            t.addIndex('i', ['key'], IndexType.standardIndex);
            t.integer('group');
          });
        var sql = schema.compile();
        expect(sql, contains('`order` int'));
        expect(sql, contains('RENAME COLUMN `order` TO `key`,'));
        expect(sql, contains('DROP COLUMN `desc`;'));
        expect(sql, contains('`i` (`key`),'));
        expect(sql, contains('ADD COLUMN `group` int;'));
      }
    });

    test('changes a column renamed or added before in another statement', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.alter('t', (t) {
          t.changeColumnType('a', ColumnType.bigInt);
          t.renameColumn('b', 'c');
          t.changeColumnType('c', ColumnType.varChar, length: 40);
          t.varChar('e', length: 9);
          t.setNotNull('e');
        });
        expect(
          schema.compile(),
          'ALTER TABLE t\n'
          '  MODIFY `a` bigint,\n'
          '  RENAME COLUMN `b` TO `c`;\n'
          'ALTER TABLE t\n'
          '  MODIFY `c` varchar(40),\n'
          '  ADD COLUMN `e` varchar(9);\n'
          'ALTER TABLE t\n'
          '  MODIFY `e` /* the type of `e` */ NOT NULL;\n',
        );
      }

      // And of the table renamed before.
      var schema = MySqlSchema()
        ..alter('t', (t) {
          t.rename('u');
          t.integer('f');
          t.dropColumn('f');
        });
      expect(schema.compile(), contains('ALTER TABLE u\n  DROP COLUMN `f`;'));
    });

    test('renames or drops a column changed before in another statement', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.alter('t', (t) {
          t.changeColumnType('a', ColumnType.bigInt);
          t.renameColumn('a', 'b');
          t.setNotNull('c');
          t.dropColumn('c');
        });
        expect(
          schema.compile(),
          'ALTER TABLE t\n'
          '  MODIFY `a` bigint;\n'
          'ALTER TABLE t\n'
          '  RENAME COLUMN `a` TO `b`,\n'
          '  MODIFY `c` /* the type of `c` */ NOT NULL;\n'
          'ALTER TABLE t\n'
          '  DROP COLUMN `c`;\n',
        );
      }
    });

    test('adds the index of a column added by MySQL and MariaDB', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.alter('t', (t) {
          t.varChar('email', length: 9).unique();
          t.integer('n');
        });
        expect(
          schema.compile(),
          'ALTER TABLE t\n'
          '  ADD COLUMN `email` varchar(9),\n'
          '  ADD UNIQUE KEY `unique_email` (`email`),\n'
          '  ADD COLUMN `n` int;\n',
        );
      }
    });

    test('PostgreSQL changes a column added before in another statement', () {
      var sql =
          (PostgresSchema()..alter('t', (t) {
                t.integer('x');
                t.changeColumnType('x', ColumnType.bigInt, defaultValue: 0);
                t.integer('y');
              }))
              .compile();
      expect(
        sql,
        'ALTER TABLE "t"\n'
        '  ADD COLUMN "x" int;\n'
        'ALTER TABLE "t"\n'
        '  ALTER COLUMN "x" DROP DEFAULT,\n'
        '  ALTER COLUMN "x" TYPE bigint,\n'
        '  ALTER COLUMN "x" SET DEFAULT 0,\n'
        '  ADD COLUMN "y" int;\n',
      );

      // And the statements of PostgresIndexes end.
      sql =
          (PostgresSchema()..indexes('t', (i) {
                i.dropPrimaryIndex();
                i.addIndex('ix', ['a'], IndexType.standardIndex);
              }))
              .compile();
      expect(sql, contains('DROP CONSTRAINT "t_pkey";\nCREATE INDEX'));
    });

    test('merges the changes of a column into one MODIFY', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.alter('t', (t) {
          t.changeColumnType('a', ColumnType.bigInt, defaultValue: 1);
          t.setNotNull('`a`');
          t.dropNotNull('b');
          t.changeColumnType('b', ColumnType.varChar, length: 9);
        });
        var sql = schema.compile();
        expect(sql, contains('MODIFY `a` bigint NOT NULL DEFAULT 1,'));
        expect(sql, contains('MODIFY `b` varchar(9);'));
        expect(RegExp('MODIFY').allMatches(sql), hasLength(2));
      }
    });

    test('renames a column of MariaDB as MySQL does', () {
      void rename(MutableTable t) => t.renameColumn('a', 'b');
      expect(
        (MariaDbSchema()..alter('t', rename)).compile(),
        contains('RENAME COLUMN `a` TO `b`;'),
      );
      expect(
        (MySqlSchema()..alter('t', rename)).compile(),
        contains('RENAME COLUMN `a` TO `b`;'),
      );
    });

    test('escapes the quotes of PostgreSQL identifiers', () {
      var sql =
          (PostgresSchema()..alter('t', (t) {
                t.changeColumnType('a"b', ColumnType.int);
                t.renameColumn('a"b', 'c');
              }))
              .compile();
      expect(sql, contains('ALTER COLUMN "a""b" TYPE int;'));
      expect(sql, contains('RENAME COLUMN "a""b" TO "c";'));
    });

    test('PostgreSQL renames in statements of their own', () {
      var sql =
          (PostgresSchema()..alter('t', (t) {
                t.dropColumn('x');
                t.renameColumn('a', 'b');
                t.rename('u');
                t.changeColumnType('b', ColumnType.serial);
                t.integer('c');
              }))
              .compile();
      expect(
        sql,
        startsWith(
          'ALTER TABLE "t"\n  DROP COLUMN "x";\n'
          'ALTER TABLE "t"\n  RENAME COLUMN "a" TO "b";\n'
          'ALTER TABLE "t"\n  RENAME TO "u";\n'
          'ALTER TABLE "u"\n  ALTER COLUMN "b" TYPE int,\n'
          '  ADD COLUMN "c" int;\n',
        ),
      );
      // The sequence is of the new names.
      expect(sql, contains('''pg_get_serial_sequence('"u"', 'b')'''));
      expect(sql, contains('CREATE SEQUENCE "u_b_seq"'));

      // A column changed before it is renamed has its sequence by its new
      // name.
      sql =
          (PostgresSchema()..alter('t', (t) {
                t.changeColumnType('a', ColumnType.serial);
                t.renameColumn('a', 'b');
              }))
              .compile();
      expect(sql, contains('CREATE SEQUENCE "t_b_seq"'));
    });

    test('noDefault removes the default', () {
      void change(MutableTable t) => t.changeColumnType(
        'c',
        ColumnType.int,
        isNullable: false,
        defaultValue: noDefault,
      );

      // Not the existing one, which an int may not have.
      var modification = ColumnModification(
        'c',
        ColumnType.int,
        length: 255,
        defaultValue: noDefault,
      )..existing = ExistingConstraints(isNullable: false, defaultValue: 'n/a');
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        'MODIFY `c` int NOT NULL',
      );
      expect(
        (MySqlSchema()..alter('t', change)).compile(),
        contains('MODIFY `c` int NOT NULL;'),
      );
      expect(
        (MariaDbSchema()..alter('t', change)).compile(),
        contains('MODIFY `c` int NOT NULL;'),
      );
      var sql = (PostgresSchema()..alter('t', change)).compile();
      expect(sql, contains('ALTER COLUMN "c" DROP DEFAULT,'));
      expect(sql, isNot(contains('SET DEFAULT')));
    });

    test('PostgreSQL changes a column to the integer of a serial type', () {
      for (var (serial, integer) in [
        (ColumnType.smallSerial, 'smallint'),
        (ColumnType.serial, 'int'),
        (ColumnType.bigSerial, 'bigint'),
      ]) {
        expect(
          (PostgresSchema()
                ..alter('t', (t) => t.changeColumnType('id', serial)))
              .compile(),
          contains('ALTER COLUMN "id" TYPE $integer'),
          reason: serial.name,
        );
      }
    });

    test('PostgreSQL gives a column changed to serial a sequence', () {
      var sql =
          (PostgresSchema()..alter(
                't',
                (t) => t.changeColumnType('id', ColumnType.bigSerial),
              ))
              .compile();
      expect(sql, contains('ALTER COLUMN "id" TYPE bigint;'));
      expect(
        sql,
        contains("""seq_name text := pg_get_serial_sequence('"t"', 'id');"""),
      );
      expect(sql, contains('CREATE SEQUENCE "t_id_seq" AS bigint'));
      // Or the sequence it has is made a bigint, if smaller.
      expect(sql, contains('< 8 THEN'));
      expect(sql, contains("ALTER SEQUENCE %s AS bigint', seq_name)"));

      // Or to autoIncrement.
      sql =
          (PostgresSchema()..alter(
                't',
                (t) => t.changeColumnType(
                  'n',
                  ColumnType.int,
                  autoIncrement: true,
                ),
              ))
              .compile();
      expect(sql, contains('CREATE SEQUENCE "t_n_seq" AS integer'));
      expect(
        (PostgresSchema()
              ..alter('t', (t) => t.changeColumnType('n', ColumnType.int)))
            .compile(),
        isNot(contains('SEQUENCE')),
      );
    });

    test('compiles an alter table again, with its changes of types', () {
      void change(MutableTable t) =>
          t.changeColumnType('n', ColumnType.bigInt, isNullable: false);

      var mySql = MySqlSchema()
        ..drop('a')
        ..alter('t', change)
        ..drop('b');
      var sql = mySql.compile();
      expect(
        sql,
        'DROP TABLE a;\nALTER TABLE t\n  MODIFY `n` bigint NOT NULL;\n'
        'DROP TABLE b;\n',
      );
      expect(mySql.compile(), sql);

      var mariaDb = MariaDbSchema()..alter('t', change);
      sql = mariaDb.compile();
      expect(sql, contains('MODIFY `n` bigint NOT NULL'));
      expect(mariaDb.compile(), sql);
    });

    test('splits the statements of MySQL', () {
      expect(
        splitMySqlStatements(
          "CREATE TABLE t (a varchar(9) DEFAULT 'x;''y\\';z');\n"
          'ALTER TABLE `a;b` MODIFY "c;" int; -- d;\n'
          '# e;\n'
          '/* f; */ DROP TABLE u;;  \n',
        ),
        [
          "CREATE TABLE t (a varchar(9) DEFAULT 'x;''y\\';z')",
          'ALTER TABLE `a;b` MODIFY "c;" int',
          '-- d;\n# e;\n/* f; */ DROP TABLE u',
        ],
      );
      expect(splitMySqlStatements(' ;\n'), isEmpty);
      // `--` without a space after it is not a comment.
      expect(splitMySqlStatements('SELECT 1--1; SELECT 2'), [
        'SELECT 1--1',
        'SELECT 2',
      ]);
    });

    test('reads the constraints of a table of another database', () {
      expect(
        existingConstraintsQuery('`shop`.`orders`', ['amount']),
        endsWith(
          "table_schema = 'shop' AND table_name = 'orders' "
          "AND column_name IN ('amount')",
        ),
      );
      expect(
        existingConstraintsQuery('orders', ['amount', 'fee']),
        endsWith(
          "table_schema = DATABASE() AND table_name = 'orders' "
          "AND column_name IN ('amount', 'fee')",
        ),
      );
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
      expect(create.compile(), contains('`amount` numeric(10, 2)'));
      expect(create.compile(), contains('`tax` decimal(5, 4)'));
      expect(
        create.compile(),
        contains('`fee` decimal(8, 1) NOT NULL DEFAULT 0'),
      );

      // Without the database, MODIFY has only the constraints given.
      var alter = MySqlSchema();
      AlterPricesMigration().up(alter);
      var sql = alter.compile();
      expect(sql, contains('MODIFY `amount` numeric(12, 4),'));
      expect(sql, contains('MODIFY `fee` decimal(10, 2),'));
      expect(sql, contains('MODIFY `id` bigint;'));
    });

    test('MariaDB', () {
      var create = MariaDbSchema();
      PricesMigration().up(create);
      expect(create.compile(), contains('`amount` numeric(10, 2)'));
      expect(create.compile(), contains('`tax` decimal(5, 4)'));
      expect(
        create.compile(),
        contains('`fee` decimal(8, 1) NOT NULL DEFAULT 0'),
      );

      // Without the database, MODIFY has only the constraints given.
      var alter = MariaDbSchema();
      AlterPricesMigration().up(alter);
      var sql = alter.compile();
      expect(sql, contains('MODIFY `amount` numeric(12, 4),'));
      expect(sql, contains('MODIFY `fee` decimal(10, 2),'));
      expect(sql, contains('MODIFY `id` bigint;'));
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
        [
          'note',
          'character varying',
          null,
          null,
          "'it''s'::character varying",
          'YES',
        ],
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

    test('removes a default that the new type cannot have', () async {
      await conn.execute('DROP TABLE IF EXISTS defaulted');
      await conn.execute(
        "CREATE TABLE defaulted (c varchar(9) NOT NULL DEFAULT 'n/a')",
      );
      await (PostgresSchema()..alter(
            'defaulted',
            (t) => t.changeColumnType(
              'c',
              ColumnType.int,
              defaultValue: noDefault,
              using: 'c::int',
            ),
          ))
          .run(conn);

      var result = await conn.execute(
        "SELECT data_type, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = current_schema() AND table_name = 'defaulted'",
      );
      expect(result.single.toList(), ['integer', 'NO', null]);
      await conn.execute('DROP TABLE defaulted');
    });

    test(
      'indexes quoted columns, and drops a column changed to serial',
      () async {
        await conn.execute('DROP TABLE IF EXISTS "Indexed"');
        await conn.execute(
          'CREATE TABLE "Indexed" ("order" int, "Name" text, x int)',
        );
        await (PostgresSchema()
              ..alter('Indexed', (t) {
                t.addIndex('indexed_order', ['order'], IndexType.unique);
                t.changeColumnType('x', ColumnType.serial);
                t.dropColumn('x');
              })
              ..indexes(
                'Indexed',
                (t) => t.addIndex('indexed_name', [
                  'Name',
                ], IndexType.standardIndex),
              ))
            .run(conn);

        var indexes = await conn.execute(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'Indexed' "
          "ORDER BY indexname",
        );
        expect(indexes.map((r) => r.first), ['indexed_name', 'indexed_order']);
        var columns = await conn.execute(
          "SELECT column_name FROM information_schema.columns "
          "WHERE table_name = 'Indexed' ORDER BY column_name",
        );
        expect(columns.map((r) => r.first), ['Name', 'order']);
        await conn.execute('DROP TABLE "Indexed"');
      },
    );

    test('changes and renames columns added before in one alter', () async {
      await conn.execute('DROP TABLE IF EXISTS added_pg');
      await conn.execute('CREATE TABLE added_pg (a int)');
      await (PostgresSchema()..alter('added_pg', (t) {
            t.integer('x');
            t.changeColumnType('x', ColumnType.bigInt, defaultValue: 0);
            t.integer('y');
            t.renameColumn('y', 'z');
          }))
          .run(conn);

      var result = await conn.execute(
        "SELECT column_name, data_type, column_default "
        "FROM information_schema.columns WHERE table_name = 'added_pg' "
        "ORDER BY column_name",
      );
      expect(result.map((r) => r.toList()), [
        ['a', 'integer', null],
        ['x', 'bigint', '0'],
        ['z', 'integer', null],
      ]);
      await conn.execute('DROP TABLE added_pg');
    });

    test('renames with other changes', () async {
      await conn.execute('DROP TABLE IF EXISTS renamed_pg, renamed_pg2');
      await conn.execute('CREATE TABLE renamed_pg (a int, x int)');
      await conn.execute('INSERT INTO renamed_pg (a) VALUES (4)');
      await (PostgresSchema()..alter('renamed_pg', (t) {
            t.dropColumn('x');
            t.renameColumn('a', 'id');
            t.rename('renamed_pg2');
            t.changeColumnType('id', ColumnType.bigSerial);
            t.varChar('note', length: 9);
          }))
          .run(conn);

      await conn.execute("INSERT INTO renamed_pg2 (note) VALUES ('n')");
      var rows = await conn.execute(
        'SELECT id, note FROM renamed_pg2 ORDER BY id',
      );
      expect(rows.map((r) => r.toList()), [
        [4, null],
        [5, 'n'],
      ]);
      await conn.execute('DROP TABLE renamed_pg2');
    });

    test('gives a column changed to serial a sequence', () async {
      await conn.execute('DROP TABLE IF EXISTS counted');
      await conn.execute('CREATE TABLE counted (id int, note text)');
      await conn.execute('INSERT INTO counted (id) VALUES (1), (5)');
      Future<List<Object?>> insert() async {
        await conn.execute("INSERT INTO counted (note) VALUES ('n')");
        var rows = await conn.execute('SELECT id FROM counted ORDER BY id');
        return [for (var row in rows) row.first];
      }

      // The sequence starts after the values.
      await (PostgresSchema()..alter(
            'counted',
            (t) => t.changeColumnType('id', ColumnType.serial),
          ))
          .run(conn);
      expect(await insert(), [1, 5, 6]);

      // The column keeps its sequence, which is changed to a bigint, and so
      // goes on after the greatest integer.
      await (PostgresSchema()..alter(
            'counted',
            (t) => t.changeColumnType('id', ColumnType.bigSerial),
          ))
          .run(conn);
      expect(await insert(), [1, 5, 6, 7]);
      await conn.execute("SELECT setval('counted_id_seq', 2147483647)");
      expect(await insert(), [1, 5, 6, 7, 2147483648]);
      var type = await conn.execute(
        "SELECT data_type FROM information_schema.sequences "
        "WHERE sequence_name = 'counted_id_seq'",
      );
      expect(type.single.single, 'bigint');

      // A smaller type does not change it.
      await (PostgresSchema()..alter(
            'counted',
            (t) => t.changeColumnType(
              'id',
              ColumnType.bigInt,
              autoIncrement: true,
            ),
          ))
          .run(conn);
      type = await conn.execute(
        "SELECT data_type FROM information_schema.sequences "
        "WHERE sequence_name = 'counted_id_seq'",
      );
      expect(type.single.single, 'bigint');
      await conn.execute('DROP TABLE counted');
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
        ['note', 'varchar', null, null, "'it''s'", 'YES', ''],
        ['rate', 'decimal', 17, 3, 'NULL', 'YES', ''],
        ['tax', 'decimal', 5, 4, 'NULL', 'YES', ''],
      ]);
    });

    test('runs a migration of more than one statement', () async {
      // Left by a run that failed.
      await conn.query('DROP TABLE IF EXISTS created');
      await conn.query(
        "DELETE FROM migrations WHERE path = 'CreateAndChangeMigration'",
      );
      runner = MariaDbMigrationRunner(
        conn,
        migrations: [CreateAndChangeMigration()],
      );
      await runner.up();

      var rows = await conn.query(
        "SELECT column_name, data_type, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'created' "
        "ORDER BY column_name",
      );
      expect(rows.map((r) => [r[0], r[1], r[2], r[3].toString()]), [
        ['c', 'bigint', 'NO', '5'],
        ['note', 'varchar', 'YES', "'x; ''y'''"],
      ]);
      rows = await conn.query(
        "SELECT index_name FROM information_schema.statistics "
        "WHERE table_schema = database() AND table_name = 'created'",
      );
      expect(rows.map((r) => r[0]), ['created_c']);
    });
  });

  // The runner for MySQL, whose client reads the constraints differently,
  // on the same server.
  group('MySQL runner', skip: skipMySql, () {
    late mysql_client.MySQLConnection conn;
    late MigrationRunner runner;

    setUp(() async {
      conn = await mysql_client.MySQLConnection.createConnection(
        host: Platform.environment['MYSQL_HOST'] ?? 'localhost',
        port: 3306,
        databaseName: Platform.environment['MYSQL_DB'] ?? 'orm_test',
        userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
        password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123',
        secure: true,
      );
      await conn.connect();
      runner = MySqlMigrationRunner(
        conn,
        migrations: [PricesMigration(), AlterPricesMigration()],
      );
    });

    tearDown(() async {
      await runner.reset();
      await conn.close();
    });

    test('keeps the constraints not given', () async {
      await runner.up();

      var result = await conn.execute(
        "SELECT column_name, is_nullable, column_default, extra "
        "FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'prices' "
        "AND column_name IN ('fee', 'id', 'note') ORDER BY column_name",
      );
      expect(result.rows.map((r) => [for (var i = 0; i < 4; i++) r.colAt(i)]), [
        ['fee', 'NO', '0.00', ''],
        ['id', 'NO', null, 'auto_increment'],
        ['note', 'YES', "'it''s'", ''],
      ]);
    });

    test('reads the constraints after the statements before', () async {
      // Left by a run that failed.
      await conn.execute('DROP TABLE IF EXISTS created');
      await conn.execute(
        "DELETE FROM migrations WHERE path = 'CreateAndChangeMigration'",
      );
      runner = MySqlMigrationRunner(
        conn,
        migrations: [CreateAndChangeMigration()],
      );
      await runner.up();

      var result = await conn.execute(
        "SELECT column_name, data_type, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'created' "
        "ORDER BY column_name",
      );
      expect(result.rows.map((r) => [for (var i = 0; i < 4; i++) r.colAt(i)]), [
        ['c', 'bigint', 'NO', '5'],
        ['note', 'varchar', 'YES', "'x; ''y'''"],
      ]);
      result = await conn.execute(
        "SELECT index_name FROM information_schema.statistics "
        "WHERE table_schema = database() AND table_name = 'created'",
      );
      expect(result.rows.map((r) => r.colAt(0)), ['created_c']);
    });

    test('removes a default that the new type cannot have', () async {
      await conn.execute('DROP TABLE IF EXISTS defaulted');
      await conn.execute(
        "CREATE TABLE defaulted (c varchar(9) NOT NULL DEFAULT 'n/a')",
      );
      await (MySqlSchema()..alter(
            'defaulted',
            (t) => t.changeColumnType(
              'c',
              ColumnType.int,
              defaultValue: noDefault,
            ),
          ))
          .run(conn);

      var result = await conn.execute(
        "SELECT data_type, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'defaulted'",
      );
      var row = result.rows.single;
      // The NOT NULL is kept. MariaDB gives no default as `NULL`.
      expect([row.colAt(0), row.colAt(1)], ['int', 'NO']);
      expect(row.colAt(2), anyOf(isNull, 'NULL'));
      await conn.execute('DROP TABLE defaulted');
    });

    test('keeps ON UPDATE when the other constraints are given', () async {
      await conn.execute('DROP TABLE IF EXISTS stamped');
      await conn.execute(
        'CREATE TABLE stamped (at datetime NOT NULL '
        'DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)',
      );
      await (MySqlSchema()..alter(
            'stamped',
            (t) => t.changeColumnType(
              'at',
              ColumnType.timeStamp,
              isNullable: false,
              defaultValue: RawSql('CURRENT_TIMESTAMP'),
              autoIncrement: false,
            ),
          ))
          .run(conn);

      var result = await conn.execute(
        "SELECT extra FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'stamped'",
      );
      expect(
        result.rows.single.colAt(0)!.toLowerCase(),
        contains('on update current_timestamp'),
      );
      await conn.execute('DROP TABLE stamped');
    });

    test('keeps UNSIGNED and generated columns', () async {
      await conn.execute('DROP TABLE IF EXISTS generated');
      await conn.execute(
        'CREATE TABLE generated (a int, u int unsigned NOT NULL DEFAULT 2, '
        's int AS (a + 1) STORED, v int AS (a * 2) VIRTUAL)',
      );
      await conn.execute('INSERT INTO generated (a) VALUES (5)');
      await (MySqlSchema()..alter('generated', (t) {
            t.changeColumnType('u', ColumnType.bigInt);
            t.changeColumnType('s', ColumnType.bigInt);
            t.changeColumnType('v', ColumnType.bigInt);
          }))
          .run(conn);

      var result = await conn.execute(
        "SELECT column_name, column_type, extra, generation_expression "
        "FROM information_schema.columns WHERE table_schema = database() "
        "AND table_name = 'generated' AND column_name <> 'a' "
        "ORDER BY column_name",
      );
      var columns = {
        for (var row in result.rows)
          row.colAt(0): [for (var i = 1; i < 4; i++) row.colAt(i)],
      };
      expect(columns['u']![0], startsWith('bigint'));
      expect(columns['u']![0], contains('unsigned'));
      expect(columns['s']![1], 'STORED GENERATED');
      expect(columns['s']![2], contains('+ 1'));
      expect(columns['v']![1], 'VIRTUAL GENERATED');
      expect(columns['v']![2], contains('* 2'));

      var values = await conn.execute('SELECT u, s, v FROM generated');
      var row = values.rows.single;
      expect([row.colAt(0), row.colAt(1), row.colAt(2)], ['2', '6', '10']);
      await conn.execute('DROP TABLE generated');
    });

    test('changes a column renamed or added before in one alter', () async {
      await conn.execute('DROP TABLE IF EXISTS renamed_my');
      await conn.execute('CREATE TABLE renamed_my (b int NOT NULL DEFAULT 7)');
      await (MySqlSchema()..alter('renamed_my', (t) {
            t.renameColumn('b', 'c');
            t.changeColumnType('c', ColumnType.bigInt);
            t.varChar('e', length: 9);
            t.setNotNull('e');
          }))
          .run(conn);

      var result = await conn.execute(
        "SELECT column_name, column_type, is_nullable, column_default "
        "FROM information_schema.columns WHERE table_schema = database() "
        "AND table_name = 'renamed_my' ORDER BY column_name",
      );
      expect(result.rows.map((r) => [for (var i = 0; i < 4; i++) r.colAt(i)]), [
        // The constraints of the column renamed are kept.
        ['c', startsWith('bigint'), 'NO', '7'],
        ['e', 'varchar(9)', 'NO', anyOf(isNull, 'NULL')],
      ]);
      await conn.execute('DROP TABLE renamed_my');
    });

    test('renames and drops columns changed before in one alter', () async {
      await conn.execute('DROP TABLE IF EXISTS changed_my');
      await conn.execute('CREATE TABLE changed_my (a int, c int)');
      await (MySqlSchema()..alter('changed_my', (t) {
            t.changeColumnType('a', ColumnType.bigInt);
            t.renameColumn('a', 'b');
            t.setNotNull('c');
            t.dropColumn('c');
            t.varChar('email', length: 9).unique();
          }))
          .run(conn);

      var result = await conn.execute(
        "SELECT column_name, column_type FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'changed_my' "
        "ORDER BY column_name",
      );
      expect(result.rows.map((r) => [r.colAt(0), r.colAt(1)]), [
        ['b', startsWith('bigint')],
        ['email', 'varchar(9)'],
      ]);
      // The column added has its unique index.
      await conn.execute("INSERT INTO changed_my (email) VALUES ('x')");
      await expectLater(
        conn.execute("INSERT INTO changed_my (email) VALUES ('x')"),
        throwsA(anything),
      );
      await conn.execute('DROP TABLE changed_my');
    });

    test('changes a column twice in one alter', () async {
      await conn.execute('DROP TABLE IF EXISTS twice');
      await conn.execute(
        'CREATE TABLE twice (a int DEFAULT 5, b int NOT NULL)',
      );
      await (MySqlSchema()..alter('twice', (t) {
            t.changeColumnType('a', ColumnType.bigInt);
            t.setNotNull('a');
            t.dropNotNull('b');
            t.changeColumnType('b', ColumnType.varChar, length: 40);
          }))
          .run(conn);

      var result = await conn.execute(
        "SELECT column_name, column_type, is_nullable, column_default "
        "FROM information_schema.columns WHERE table_schema = database() "
        "AND table_name = 'twice' ORDER BY column_name",
      );
      expect(result.rows.map((r) => [for (var i = 0; i < 4; i++) r.colAt(i)]), [
        ['a', startsWith('bigint'), 'NO', '5'],
        ['b', 'varchar(40)', 'YES', anyOf(isNull, 'NULL')],
      ]);
      await conn.execute('DROP TABLE twice');
    });

    test('alters columns named as reserved words', () async {
      await conn.execute('DROP TABLE IF EXISTS reserved');
      var schema = MySqlSchema()
        ..create('reserved', (t) {
          t.integer('order');
          t.integer('desc');
        });
      await schema.run(conn);
      schema = MySqlSchema()
        ..alter('reserved', (t) {
          t.renameColumn('order', 'key');
          t.dropColumn('desc');
          t.addIndex('reserved_key', ['key'], IndexType.standardIndex);
          t.integer('group');
        });
      await schema.run(conn);

      var result = await conn.execute(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'reserved' "
        "ORDER BY column_name",
      );
      expect(result.rows.map((r) => r.colAt(0)), ['group', 'key']);
      await conn.execute('DROP TABLE reserved');
    });

    test('changes a column given in backticks', () async {
      await conn.execute('DROP TABLE IF EXISTS quoted');
      await conn.execute(
        'CREATE TABLE quoted (`order` int NOT NULL DEFAULT 1)',
      );
      await (MySqlSchema()..alter(
            'quoted',
            (t) => t.changeColumnType('`order`', ColumnType.bigInt),
          ))
          .run(conn);

      var result = await conn.execute(
        "SELECT data_type, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = database() AND table_name = 'quoted'",
      );
      var row = result.rows.single;
      expect([row.colAt(0), row.colAt(1), row.colAt(2)], ['bigint', 'NO', '1']);
      await conn.execute('DROP TABLE quoted');
    });

    test('sets and drops NOT NULL, keeping the type', () async {
      await conn.execute('DROP TABLE IF EXISTS nullity');
      await conn.execute(
        'CREATE TABLE nullity (a int unsigned DEFAULT 3, '
        'id int NOT NULL, KEY (id))',
      );
      Future<List<String?>> column(String name) async {
        var result = await conn.execute(
          "SELECT column_type, is_nullable, column_default, extra "
          "FROM information_schema.columns WHERE table_schema = database() "
          "AND table_name = 'nullity' AND column_name = '$name'",
        );
        var row = result.rows.single;
        return [for (var i = 0; i < 4; i++) row.colAt(i)];
      }

      await (MySqlSchema()..alter('nullity', (t) => t.setNotNull('a'))).run(
        conn,
      );
      var a = await column('a');
      expect(a[0], contains('unsigned'));
      expect(a.sublist(1, 3), ['NO', '3']);

      await (MySqlSchema()..alter('nullity', (t) => t.dropNotNull('a'))).run(
        conn,
      );
      expect((await column('a'))[1], 'YES');

      // A serial type is its integer, with AUTO_INCREMENT.
      await (MySqlSchema()..alter(
            'nullity',
            (t) => t.changeColumnType('id', ColumnType.bigSerial),
          ))
          .run(conn);
      var id = await column('id');
      expect(id[0], startsWith('bigint'));
      expect(id[3], 'auto_increment');
      await conn.execute('DROP TABLE nullity');
    });

    test('throws for a column that is not found', () async {
      await conn.execute('DROP TABLE IF EXISTS missing');
      await conn.execute('CREATE TABLE missing (a int NOT NULL)');
      var schema = MySqlSchema()
        ..alter('missing', (t) => t.changeColumnType('b', ColumnType.bigInt));
      await expectLater(schema.run(conn), throwsA(isA<StateError>()));
      await conn.execute('DROP TABLE missing');
    });

    test('throws, and does not record a migration that fails', () async {
      Future<int> count() async => int.parse(
        (await conn.execute('SELECT COUNT(*) FROM migrations')).rows.first
            .colAt(0)!,
      );
      var failing = MySqlMigrationRunner(
        conn,
        migrations: [FailingMigration()],
      );
      var before = await count();
      await expectLater(failing.up(), throwsA(anything));
      expect(await count(), before);
    });
  });
}
