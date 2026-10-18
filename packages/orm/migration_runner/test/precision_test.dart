import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql1/mysql1.dart' as mysql1;
import 'package:mysql_client/mysql_client.dart' as mysql_client;
import 'package:mysql_client/exception.dart' as mysql_errors;
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

/// A table of MySQL or MariaDB with an integer with a default, a column of
/// text with a collation and a comment, and one with a literal default.
const _keptTable =
    'CREATE TABLE kept ('
    'id int NOT NULL DEFAULT 0, '
    "code varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'sku', "
    "note varchar(20) DEFAULT 'x', "
    'PRIMARY KEY (id))';

/// Makes `id` of [_keptTable] AUTO_INCREMENT, `code` NOT NULL, and `note` a
/// TEXT.
void _alterKept(MutableTable t) {
  t.changeColumnType('id', ColumnType.serial);
  t.setNotNull('code');
  t.changeColumnType('note', ColumnType.text);
}

const _keptColumns =
    'SELECT column_name, column_default, extra, is_nullable, '
    'collation_name, column_comment FROM information_schema.columns '
    "WHERE table_schema = database() AND table_name = 'kept' "
    'ORDER BY column_name';

/// Expects [rows] of [_keptColumns] after [_alterKept].
void _expectKept(List<List<String?>> rows) {
  var [code, id, note] = rows;
  // The default of `id`, which an AUTO_INCREMENT column cannot have, is
  // dropped. MariaDB gives no default as `NULL`.
  expect(id[1], anyOf(isNull, 'NULL'));
  expect(id[2], contains('auto_increment'));
  expect([code[3], code[4], code[5]], ['NO', 'utf8mb4_bin', 'sku']);
  // MariaDB keeps the literal; MySQL has it as an expression.
  expect(note[1], contains('x'));
}

/// An integer column with a standard index.
const _indexedInt = Column(
  type: ColumnType.int,
  indexType: IndexType.standardIndex,
);

/// Creates a table that [ChildMigration] references.
class ParentMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('parents', (t) => t.serial('id').primaryKey());
  }

  @override
  void down(Schema schema) {
    schema.drop('parents');
  }
}

/// Creates a table that references that of [ParentMigration], so it must be
/// rolled back first.
class ChildMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('children', (t) {
      t.serial('id').primaryKey();
      t.integer('parent_id').references('parents', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('children');
  }
}

/// Creates the table `atomic`, under [name].
class _AtomicMigration extends Migration {
  @override
  final String name;

  _AtomicMigration(this.name);

  @override
  void up(Schema schema) {
    schema.create('atomic', (t) => t.integer('a'));
  }

  @override
  void down(Schema schema) {
    schema.drop('atomic');
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
          columnType: 'int(10) unsigned',
        );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        "MODIFY `a` int(10) unsigned NOT NULL DEFAULT '3'",
      );
      modification = ColumnModification.nullability('a', isNullable: false)
        ..existing = ExistingConstraints(
          isNullable: true,
          autoIncrement: true,
          columnType: 'int(10) unsigned',
        );
      expect(
        modification.compile(MySqlGenerator.compileColumn),
        'MODIFY `a` int(10) unsigned NOT NULL AUTO_INCREMENT',
      );
    });

    test('drops the default of a column made AUTO_INCREMENT', () {
      for (var (type, autoIncrement) in [
        (ColumnType.serial, null),
        (ColumnType.int, true),
      ]) {
        var modification =
            ColumnModification(
                'id',
                type,
                length: 255,
                autoIncrement: autoIncrement,
              )
              ..existing = ExistingConstraints(
                isNullable: false,
                defaultValue: '0',
                isKey: true,
              );
        expect(
          modification.compile(MySqlGenerator.compileColumn),
          'MODIFY `id` int NOT NULL AUTO_INCREMENT',
        );
      }
    });

    test('makes a serial column AUTO_INCREMENT only if it is a key', () {
      String change({required bool isKey}) =>
          (ColumnModification('n', ColumnType.serial, length: 255)
                ..existing = ExistingConstraints(
                  isNullable: false,
                  defaultValue: '0',
                  isKey: isKey,
                ))
              .compile(MySqlGenerator.compileColumn);
      expect(change(isKey: true), 'MODIFY `n` int NOT NULL AUTO_INCREMENT');
      expect(change(isKey: false), "MODIFY `n` int NOT NULL DEFAULT '0'");
    });

    test('keeps a column INVISIBLE', () {
      var e = ExistingConstraints.parse(
        isNullable: 'YES',
        columnDefault: null,
        extra: 'INVISIBLE',
        version: '8.4.0',
        columnType: 'int',
      );
      expect(e.invisible, isTrue);
      expect(
        (ColumnModification.nullability(
          'secret',
          isNullable: false,
        )..existing = e).compile(MySqlGenerator.compileColumn),
        'MODIFY `secret` int NOT NULL INVISIBLE',
      );
    });

    test('drops the json_valid of a JSON column changed to another type', () {
      var existing = ExistingConstraints(
        isNullable: true,
        columnType: 'longtext',
        check: 'json_valid(`data`)',
      );
      expect(
        (ColumnModification(
          'data',
          ColumnType.varChar,
          length: 20,
        )..existing = existing).compile(MariaDbGenerator.compileColumn),
        'MODIFY `data` varchar(20)',
      );
      expect(
        (ColumnModification(
          'data',
          ColumnType.json,
          length: 255,
        )..existing = existing).compile(MariaDbGenerator.compileColumn),
        'MODIFY `data` json CHECK (json_valid(`data`))',
      );
      // Another CHECK is kept.
      expect(
        (ColumnModification('p', ColumnType.bigInt, length: 255)
              ..existing = ExistingConstraints(
                isNullable: true,
                check: '`p` > 0',
              ))
            .compile(MariaDbGenerator.compileColumn),
        'MODIFY `p` bigint CHECK (`p` > 0)',
      );
    });

    test('quotes each part of the table of an index', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.indexes('shop.orders', (t) {
          t.addIndex('i', ['a'], IndexType.standardIndex);
          t.dropIndex('j');
          t.dropPrimaryIndex();
        });
        var sql = schema.compile();
        expect(sql, contains('`i` ON `shop`.`orders` (`a`);'));
        expect(sql, contains('`j` ON `shop`.`orders`;'));
        expect(sql, contains('DROP INDEX `PRIMARY` ON `shop`.`orders`;'));
      }
    });

    test('writes an index column that is not a name as it is', () {
      for (var (column, mySql, postgres) in [
        ('order', '`order`', '"order"'),
        // In either quotes, quoted for the database.
        ('`a b`', '`a b`', '"a b"'),
        ('"a b"', '`a b`', '"a b"'),
        ('body(100)', 'body(100)', 'body(100)'),
        ('email DESC', 'email DESC', 'email DESC'),
        ('lower(email)', 'lower(email)', 'lower(email)'),
      ]) {
        expect(compileIndexColumn(column, quoteMySqlPart), mySql);
        expect(compileIndexColumn(column, quotePostgresPart), postgres);
      }
      var schema = MySqlSchema()
        ..indexes(
          'posts',
          (t) => t.addIndex('i', ['body(100)', 'id'], IndexType.standardIndex),
        )
        ..alter(
          'posts',
          (t) => t.addIndex('j', ['title DESC'], IndexType.standardIndex),
        );
      expect(schema.compile(), contains('`i` ON `posts` (body(100),`id`);'));
      expect(schema.compile(), contains('ADD INDEX `j` (title DESC)'));
      var pg = PostgresSchema()
        ..indexes(
          'users',
          (t) => t.addIndex('u', ['lower(email)'], IndexType.unique),
        );
      expect(pg.compile(), contains('ON "users" (lower(email));'));
    });

    test('quotes each part of a table of PostgreSQL', () {
      var schema = PostgresSchema()
        ..create('audit.events', (t) {
          t.serial('id');
          t.integer('user_id').references('auth.users', 'id');
        })
        ..alter('audit.events', (t) {
          t.changeColumnType('id', ColumnType.bigSerial);
          t.rename('logs');
        })
        ..drop('"order"');
      var sql = schema.compile();
      expect(sql, contains('CREATE TABLE "audit"."events" ('));
      expect(sql, contains('REFERENCES "auth"."users"("id")'));
      expect(sql, contains('ALTER TABLE "audit"."events"'));
      // Renamed in its schema, of which its sequence is.
      expect(sql, contains('RENAME TO "logs"'));
      expect(sql, contains('"audit"."logs_id_seq"'));
      expect(sql, contains('DROP TABLE "order";'));
      expect(
        (PostgresSchema()..indexes('audit.events', (t) => t.dropPrimaryIndex()))
            .compile(),
        contains('ALTER TABLE "audit"."events" DROP CONSTRAINT "events_pkey";'),
      );
    });

    test('names the constraints, indexes and sequences of a schema', () {
      var sql =
          (PostgresSchema()
                ..alter('audit.events', (t) {
                  t.dropPrimaryIndex();
                  t.changeColumnType('"Id"', ColumnType.serial);
                })
                ..indexes('audit.events', (t) => t.dropIndex('"Ix"')))
              .compile();
      expect(sql, contains('DROP CONSTRAINT "events_pkey"'));
      expect(sql, contains('DROP INDEX "audit"."Ix";'));
      // The column's own name, without its quotes.
      expect(sql, contains('"audit"."events_Id_seq"'));
      expect(
        sql,
        contains("pg_get_serial_sequence('\"audit\".\"events\"', 'Id')"),
      );
      expect(sql, contains('ALTER COLUMN "Id" SET DEFAULT'));
    });

    test('renames a table of PostgreSQL only in its schema', () {
      String renamed(String table, String newName) =>
          (PostgresSchema()..alter(table, (t) => t.rename(newName))).compile();
      expect(renamed('audit.events', 'logs'), contains('RENAME TO "logs";'));
      expect(
        renamed('audit.events', 'audit.logs'),
        contains('RENAME TO "logs";'),
      );
      // Not to another schema.
      expect(() => renamed('audit.events', 'other.logs'), throwsArgumentError);
    });

    test('quotes a name once, whose quotes may be its own', () {
      expect(quotePostgresTableName('"""t"""'), '"""t"""');
      expect(quotePostgresTableName('a."b.c"'), '"a"."b.c"');
      expect(quoteMySqlTableName('```t```'), '```t```');
      expect(quoteMySqlTableName('a.`b.c`'), '`a`.`b.c`');
      // In double quotes too, as earlier versions took them.
      expect(quoteMySqlTableName('"orders"'), '`orders`');
      expect(quoteMySqlTableName('"my.table"'), '`my.table`');
      expect(
        existingConstraintsQuery('"shop"."t"', ['a']),
        contains("table_schema = 'shop' AND table_name = 't'"),
      );
      // An index column too.
      expect(compileIndexColumn('"""a"""', quotePostgresPart), '"""a"""');
      expect(compileIndexColumn('```x```', quoteMySqlPart), '```x```');
    });

    test('tracks a column given in quotes or not as one', () {
      var sql =
          (PostgresSchema()..alter('t', (t) {
                t.changeColumnType('"Id"', ColumnType.serial);
                t.renameColumn('Id', 'Key');
              }))
              .compile();
      expect(sql, contains('OWNED BY "t"."Key"'));
      sql =
          (PostgresSchema()..alter('t', (t) {
                t.changeColumnType('"Id"', ColumnType.serial);
                t.dropColumn('Id');
              }))
              .compile();
      expect(sql, isNot(contains('CREATE SEQUENCE')));
    });

    test('renames an unqualified table to a name of a schema', () {
      var sql =
          (PostgresSchema()..alter('users', (t) {
                t.rename('public.members');
                t.setNotNull('x');
              }))
              .compile();
      expect(sql, contains('RENAME TO "members";'));
      // Where RENAME TO leaves it, which is known by its own name.
      expect(sql, contains('ALTER TABLE "members"\n  ALTER COLUMN "x"'));
    });

    test('creates a standard index of a PostgreSQL alter table', () {
      var sql =
          (PostgresSchema()..alter('t', (t) {
                t.integer('a');
                t.addIndex('t_a', ['a'], IndexType.standardIndex);
                t.setNotNull('a');
              }))
              .compile();
      expect(
        sql,
        'ALTER TABLE "t"\n  ADD COLUMN "a" int;\n'
        'CREATE INDEX IF NOT EXISTS "t_a" ON "t" ("a");\n'
        'ALTER TABLE "t"\n  ALTER COLUMN "a" SET NOT NULL;\n',
      );
    });

    test('tells a column added in quotes from one not', () {
      var sql =
          (PostgresSchema()..alter('t', (t) {
                t.integer('"Id"');
                t.setNotNull('Id');
              }))
              .compile();
      // In another statement, as the column is added by the one before.
      expect(sql, contains('"Id" int;\nALTER TABLE "t"\n  ALTER COLUMN "Id"'));
      // On MySQL, a column in double quotes, which MySQL reads as a string, is
      // that name with its quotes, as where its constraints are read.
      expect(
        (ColumnModification(
          '"a"',
          ColumnType.bigInt,
          length: 255,
        )).compile(MySqlGenerator.compileColumn),
        'MODIFY `"a"` bigint',
      );
      expect(
        existingConstraintsQuery('t', ['"a"', '`b`']),
        endsWith("column_name IN ('\"a\"', 'b')"),
      );
      // And its unique index is named after it the same way.
      expect(
        MySqlGenerator.compileIndex(
          '"email"',
          MigrationColumn(ColumnType.varChar)..unique(),
        ),
        contains('`unique_"email"`'),
      );
    });

    test('drops an index of a PostgreSQL alter table, of either kind', () {
      var sql = (PostgresSchema()..alter('audit.t', (t) => t.dropIndex('t_a')))
          .compile();
      // The constraint, or else the index, or an error for neither.
      expect(sql, startsWith('DO \$index\$\n'));
      expect(
        sql,
        contains(
          'ALTER TABLE "audit"."t" DROP CONSTRAINT "t_a";\n'
          '  ELSIF EXISTS',
        ),
      );
      expect(sql, contains('to_regclass(\'"audit"."t_a"\')'));
      expect(sql, contains('    DROP INDEX "audit"."t_a";\n  ELSE\n'));
      expect(sql, contains('RAISE EXCEPTION'));
    });

    test('creates a unique index of an expression of an alter table', () {
      var sql =
          (PostgresSchema()..alter(
                't',
                (t) => t.addIndex('t_e', ['lower(email)'], IndexType.unique),
              ))
              .compile();
      expect(
        sql,
        contains(
          'CREATE UNIQUE INDEX IF NOT EXISTS "t_e" ON "t" (lower(email));',
        ),
      );
      // A primary key is of columns only.
      for (var add in <void Function()>[
        () =>
            PostgresAlterTable('t')
                .addIndex('p', ['lower(a)'], IndexType.primaryKey),
        () =>
            PostgresIndexes('t')
                .addIndex('p', ['a DESC'], IndexType.primaryKey),
        () =>
            MysqlAlterTable('t').addIndex('p', ['a(10)'], IndexType.primaryKey),
        () => MysqlIndexes('t').addIndex('p', ['a(10)'], IndexType.primaryKey),
      ]) {
        expect(add, throwsArgumentError);
      }
    });

    test('creates the standard index of a column of PostgreSQL', () {
      var sql =
          (PostgresSchema()
                ..create('t', (t) => t.declareColumn('a', _indexedInt))
                ..alter('t', (t) => t.declareColumn('b', _indexedInt)))
              .compile();
      expect(
        sql,
        contains(');\nCREATE INDEX IF NOT EXISTS "t_a_idx" ON "t" ("a");'),
      );
      expect(
        sql,
        contains(
          'ADD COLUMN "b" int;\nCREATE INDEX IF NOT EXISTS "t_b_idx" ON "t" ("b");',
        ),
      );
    });

    test('drops an index of PostgreSQL given with its schema', () {
      var indexes = PostgresIndexes('audit.events')
        ..dropIndex('other.events_idx')
        ..dropIndex('events_ix');
      var first = StringBuffer(), second = StringBuffer();
      indexes
        ..compile(first)
        ..compile(second);
      expect(first.toString(), contains('DROP INDEX "other"."events_idx";'));
      expect(first.toString(), contains('DROP INDEX "audit"."events_ix";'));
      // It may be compiled again.
      expect(second.toString(), first.toString());
    });

    test('changes a column to a serial type without its default', () {
      var sql =
          (PostgresSchema()..alter(
                't',
                (t) => t.changeColumnType(
                  'id',
                  ColumnType.serial,
                  defaultValue: noDefault,
                ),
              ))
              .compile();
      expect(sql, contains('DROP DEFAULT'));
      expect(sql, contains('TYPE int;'));
      expect(sql, isNot(contains('nextval')));
    });

    test('quotes a default that is not a number of PostgreSQL', () {
      expect(PostgresGenerator.compileDefault(double.nan), "'NaN'");
      expect(PostgresGenerator.compileDefault(double.infinity), "'Infinity'");
      expect(
        PostgresGenerator.compileDefault(double.negativeInfinity),
        "'-Infinity'",
      );
      // MySQL and MariaDB have none.
      expect(
        () =>
            MySqlSchema()
              ..create('t', (t) => t.float('x').defaultsTo(double.nan)),
        throwsArgumentError,
      );
    });

    test('compiles an alter table of PostgreSQL again', () {
      var table = PostgresAlterTable('t')
        ..changeColumnType('id', ColumnType.bigSerial);
      var first = StringBuffer(), second = StringBuffer();
      table
        ..compile(first, 0)
        ..compileSequences(first)
        ..compile(second, 0)
        ..compileSequences(second);
      expect(second.toString(), first.toString());
      expect(first.toString(), contains('nextval'));
    });

    test('quotes the tables of MySQL and MariaDB', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema
          ..create('order', (t) => t.integer('a'))
          ..drop('shop.group')
          ..alter('`order`', (t) => t.rename('select'));
        var sql = schema.compile();
        expect(sql, contains('CREATE TABLE `order` ('));
        expect(sql, contains('DROP TABLE `shop`.`group`;'));
        expect(sql, contains('ALTER TABLE `order`\n  RENAME TO `select`;'));
      }
    });

    test('quotes a DateTime default', () {
      var at = DateTime(2020, 1, 2, 3, 4, 5);
      for (var escape in [true, false]) {
        expect(
          compileDefault(at, escapeBackslashes: escape),
          "'2020-01-02 03:04:05.000'",
        );
        expect(
          compileDefault(DateTime.utc(2020), escapeBackslashes: escape),
          "'2020-01-01 00:00:00.000'",
        );
        expect(compileDefault(true, escapeBackslashes: escape), 'true');
        expect(compileDefault(1.5, escapeBackslashes: escape), '1.5');
      }
      // PostgreSQL keeps a UTC one so, and not of the time zone of the session.
      expect(
        PostgresGenerator.compileDefault(DateTime.utc(2020)),
        "'2020-01-01 00:00:00.000+00'",
      );
      expect(PostgresGenerator.compileDefault(at), "'2020-01-02 03:04:05.000'");
    });

    test('reads the constraints again for the typed error 1054', () async {
      var queries = <String>[];
      await (MySqlSchema()..alter('t', (t) => t.setNotNull('a'))).runWith(
        execute: (s) async {},
        query: (q) async {
          queries.add(q);
          if (q.contains('GENERATION_EXPRESSION')) {
            // Of its code, with no code in its text.
            throw const mysql_errors.MySQLServerException(
              'Champ inconnu',
              1054,
            );
          }
          return [
            [
              'a', 'YES', null, '', 'int', '5.6.51', 'int(11)', //
              null, null, null, '', '',
            ],
          ];
        },
      );
      expect(queries, hasLength(2));
    });

    test('reads the constraints again for MySQL error 1054', () async {
      var queries = <String>[];
      var schema = MySqlSchema()..alter('t', (t) => t.setNotNull('a'));
      var sql = <String>[];
      await schema.runWith(
        execute: (s) async => sql.add(s),
        query: (q) async {
          queries.add(q);
          if (q.contains('GENERATION_EXPRESSION')) {
            // In the language of the server, without the column's name.
            throw Exception('Error 1054 (42S22): Colonne inconnue');
          }
          return [
            [
              'a',
              'YES',
              null,
              '',
              'int',
              '5.6.51',
              'int(11)',
              null,
              null,
              null,
              '',
              '',
            ],
          ];
        },
      );
      expect(queries, hasLength(2));
      expect(queries.last, isNot(contains('GENERATION_EXPRESSION')));
      expect(sql.single, contains('MODIFY `a` int(11) NOT NULL'));

      // Not another error with 1054 in its text, but not as its code.
      await expectLater(
        (MySqlSchema()..alter('t-1054', (t) => t.setNotNull('a'))).runWith(
          execute: (s) async {},
          query: (q) async => throw Exception(
            "Error 1146 (42S02): Table 'orm_test.t-1054' doesn't exist",
          ),
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('1146')),
        ),
      );
      // Nor another error, which quotes the query.
      await expectLater(
        (MySqlSchema()..alter('t', (t) => t.setNotNull('a'))).runWith(
          execute: (s) async {},
          query: (q) async => throw Exception(
            "Error 1064 (42000): syntax error near 'GENERATION_EXPRESSION, "
            "CHARACTER_SET_NAME'",
          ),
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('1064')),
        ),
      );
    });

    test('quotes the table and column of a reference', () {
      for (var schema in [MySqlSchema(), MariaDbSchema()]) {
        schema.create(
          't',
          (t) => t.integer('order_id').references('shop.order', 'id'),
        );
        expect(
          schema.compile(),
          contains('`order_id` int REFERENCES `shop`.`order`(`id`)'),
        );
      }
    });

    test('keeps a literal default of a TEXT column where the server can', () {
      ColumnModification note(String version) =>
          ColumnModification('note', ColumnType.text, length: 255)
            ..existing = ExistingConstraints(
              isNullable: true,
              defaultValue: "it's",
              version: version,
            );
      // MySQL takes an expression from 8.0.13, and no default before.
      expect(
        note('8.4.0').compile(MySqlGenerator.compileColumn),
        "MODIFY `note` text DEFAULT ('it''s')",
      );
      expect(
        note('8.0.12').compile(MySqlGenerator.compileColumn),
        'MODIFY `note` text',
      );
      // MariaDB takes a literal from 10.2.1.
      expect(
        note('11.4.2-MariaDB').compile(MariaDbGenerator.compileColumn),
        "MODIFY `note` text DEFAULT 'it''s'",
      );
      expect(
        note('10.1.48-MariaDB').compile(MariaDbGenerator.compileColumn),
        'MODIFY `note` text',
      );
    });

    test('keeps the character set, collation and comment of a column', () {
      var existing = ExistingConstraints(
        isNullable: true,
        columnType: 'varchar(10)',
        characterSet: 'utf8mb4',
        collation: 'utf8mb4_bin',
        comment: "the 'sku'",
      );
      expect(
        (ColumnModification.nullability(
          'code',
          isNullable: false,
        )..existing = existing).compile(MySqlGenerator.compileColumn),
        'MODIFY `code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin '
        "NOT NULL COMMENT 'the ''sku'''",
      );
      expect(
        (ColumnModification(
          'code',
          ColumnType.varChar,
          length: 20,
        )..existing = existing).compile(MySqlGenerator.compileColumn),
        'MODIFY `code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin '
        "COMMENT 'the ''sku'''",
      );
      // A column of another type has no collation.
      expect(
        (ColumnModification(
          'code',
          ColumnType.int,
          length: 255,
        )..existing = existing).compile(MySqlGenerator.compileColumn),
        "MODIFY `code` int COMMENT 'the ''sku'''",
      );
    });

    test('reads GENERATION_EXPRESSION unless the server has none', () {
      expect(
        existingConstraintsQuery('t', ['a']),
        contains('GENERATION_EXPRESSION'),
      );
      expect(
        existingConstraintsQuery('t', ['a'], generationExpressions: false),
        isNot(contains('GENERATION_EXPRESSION')),
      );
    });

    test('throws for a generated column without its expression', () {
      for (var extra in [
        'VIRTUAL GENERATED',
        'STORED GENERATED',
        'PERSISTENT',
      ]) {
        expect(
          () => ExistingConstraints.parse(
            isNullable: 'YES',
            columnDefault: null,
            extra: extra,
            version: '10.1.48-MariaDB',
          ),
          throwsStateError,
          reason: extra,
        );
      }
      // A default of an expression is not a generation.
      expect(
        ExistingConstraints.parse(
          isNullable: 'YES',
          columnDefault: 'rand()',
          extra: 'DEFAULT_GENERATED',
          version: '8.4.0',
        ).generationExpression,
        isNull,
      );
    });

    test('reads the version of Aurora MySQL, which has no patch', () {
      var aurora = ExistingConstraints(
        isNullable: true,
        version: '8.0.mysql_aurora.3.05.2',
      );
      expect((aurora.blobDefault('x') as RawSql).value, "('x')");
      var old = ExistingConstraints(
        isNullable: true,
        version: '5.7.mysql_aurora.2.11.2',
      );
      expect(old.blobDefault('x'), isNull);
    });

    test('puts an expression default of a TEXT in parentheses', () {
      var existing = ExistingConstraints(isNullable: true, version: '8.4.0');
      expect(
        (existing.blobDefault(RawSql('(1)+(2)')) as RawSql).value,
        '((1)+(2))',
      );
    });

    test('drops the default of a column changed to JSON', () {
      for (var (compileColumn, version) in [
        (MySqlGenerator.compileColumn, '8.4.0'),
        (MariaDbGenerator.compileColumn, '11.4.2-MariaDB'),
      ]) {
        expect(
          (ColumnModification('c', ColumnType.json, length: 255)
                ..existing = ExistingConstraints(
                  isNullable: true,
                  defaultValue: 'x',
                  version: version,
                ))
              .compile(compileColumn),
          'MODIFY `c` json',
        );
      }
    });

    test('keeps no character set of a column changed to nvarchar', () {
      expect(
        (ColumnModification('c', ColumnType.nVarChar, length: 20)
              ..existing = ExistingConstraints(
                isNullable: true,
                characterSet: 'utf8mb4',
                collation: 'utf8mb4_bin',
              ))
            .compile(MySqlGenerator.compileColumn),
        'MODIFY `c` nvarchar(20)',
      );
    });

    test('keeps the CHECK of a column of MariaDB', () {
      expect(hasColumnChecks('11.4.2-MariaDB'), isTrue);
      expect(hasColumnChecks('10.2.21-MariaDB'), isFalse);
      expect(hasColumnChecks('8.4.0'), isFalse);
      expect(
        columnChecksQuery('`shop`.`t`', ['data'], version: '11.4.2-MariaDB'),
        endsWith(
          "CONSTRAINT_SCHEMA = 'shop' AND TABLE_NAME = 't' "
          "AND LEVEL = 'Column' AND CONSTRAINT_NAME IN ('data')",
        ),
      );
      // MariaDB before 10.5.10 has no LEVEL.
      expect(
        columnChecksQuery('t', ['data'], version: '10.5.9-MariaDB'),
        isNot(contains('LEVEL')),
      );
      expect(
        (ColumnModification.nullability('data', isNullable: false)
              ..existing = ExistingConstraints(
                isNullable: true,
                columnType: 'longtext',
                characterSet: 'utf8mb4',
                collation: 'utf8mb4_bin',
                check: 'json_valid(`data`)',
              ))
            .compile(MariaDbGenerator.compileColumn),
        'MODIFY `data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin '
        'NOT NULL CHECK (json_valid(`data`))',
      );
    });

    test('splits a qualified name only at dots out of quotes', () {
      expect(splitQualifiedName('`shop`.`orders`'), ['shop', 'orders']);
      expect(splitQualifiedName('shop.orders'), ['shop', 'orders']);
      expect(splitQualifiedName('`my.table`'), ['my.table']);
      expect(splitQualifiedName('`a``.b`.`c`'), ['a`.b', 'c']);
      expect(splitQualifiedName('"x.y"'), ['x.y']);
      expect(
        existingConstraintsQuery('`my.table`', ['a']),
        contains("table_schema = DATABASE() AND table_name = 'my.table'"),
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
          'ALTER TABLE `t`\n'
          '  MODIFY `a` bigint,\n'
          '  RENAME COLUMN `b` TO `c`;\n'
          'ALTER TABLE `t`\n'
          '  MODIFY `c` varchar(40),\n'
          '  ADD COLUMN `e` varchar(9);\n'
          'ALTER TABLE `t`\n'
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
      expect(schema.compile(), contains('ALTER TABLE `u`\n  DROP COLUMN `f`;'));
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
          'ALTER TABLE `t`\n'
          '  MODIFY `a` bigint;\n'
          'ALTER TABLE `t`\n'
          '  RENAME COLUMN `a` TO `b`,\n'
          '  MODIFY `c` /* the type of `c` */ NOT NULL;\n'
          'ALTER TABLE `t`\n'
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
          'ALTER TABLE `t`\n'
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
        'DROP TABLE `a`;\nALTER TABLE `t`\n  MODIFY `n` bigint NOT NULL;\n'
        'DROP TABLE `b`;\n',
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

    test('rolls back the migrations of a batch newest first', () async {
      await conn.execute('DROP TABLE IF EXISTS children, parents');
      await PostgresMigrationRunner(
        conn,
        migrations: [ParentMigration(), ChildMigration()],
      ).up();
      // Given in another order, which is not that they were run in.
      await PostgresMigrationRunner(
        conn,
        migrations: [ChildMigration(), ParentMigration()],
      ).rollback();
      var tables = await conn.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_name IN ('parents', 'children')",
      );
      expect(tables, isEmpty);
    });

    test('changes an identity column to a serial type', () async {
      await conn.execute('DROP TABLE IF EXISTS ident');
      await conn.execute(
        'CREATE TABLE ident (id int GENERATED BY DEFAULT AS IDENTITY, n int)',
      );
      await (PostgresSchema()..alter(
            'ident',
            (t) => t.changeColumnType('id', ColumnType.bigSerial),
          ))
          .run(conn);
      await conn.execute('INSERT INTO ident (n) VALUES (1)');
      var r = await conn.execute(
        "SELECT data_type, is_identity FROM information_schema.columns "
        "WHERE table_name = 'ident' AND column_name = 'id'",
      );
      expect(r.single.toList(), ['bigint', 'YES']);
      await conn.execute('DROP TABLE ident');
    });

    test('skips a migration added again, but not one of other changes', () {
      // The same changes.
      var runner = PostgresMigrationRunner(
        conn,
        migrations: [_AtomicMigration('a'), _AtomicMigration('a')],
      );
      expect(runner.compileUp(_AtomicMigration('a')), contains('"atomic"'));
      expect(
        runner.compileUp(_AtomicMigration('a')),
        runner.compileUp(_AtomicMigration('b')),
      );
      expect(
        runner.compileUp(_AtomicMigration('a')),
        isNot(runner.compileUp(ParentMigration())),
      );
    });

    test('runs and records a migration in one transaction', () async {
      await conn.execute('DROP TABLE IF EXISTS atomic');
      // Its name is too long for the migrations table, so it is not
      // recorded, and its table is not created either.
      var runner = PostgresMigrationRunner(
        conn,
        migrations: [_AtomicMigration('x' * 600)],
      );
      await expectLater(runner.up(), throwsA(anything));
      var r = await conn.execute(
        "SELECT 1 FROM information_schema.tables WHERE table_name = 'atomic'",
      );
      expect(r, isEmpty);
    });

    test('creates and drops the indexes of an alter table', () async {
      await conn.execute('DROP TABLE IF EXISTS indexed');
      Future<List<Object?>> indexes() async => [
        for (var row in await conn.execute(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'indexed' "
          'ORDER BY indexname',
        ))
          row[0],
      ];
      await (PostgresSchema()
            ..create('indexed', (t) => t.declareColumn('a', _indexedInt))
            ..alter('indexed', (t) {
              t.declareColumn('b', _indexedInt);
              t.addIndex('indexed_ab', ['a', 'b'], IndexType.standardIndex);
              t.addIndex('indexed_u', ['b'], IndexType.unique);
            }))
          .run(conn);
      expect(await indexes(), [
        'indexed_a_idx',
        'indexed_ab',
        'indexed_b_idx',
        'indexed_u',
      ]);
      // The down of the up above, of an index and of a constraint.
      await (PostgresSchema()..alter('indexed', (t) {
            t.dropIndex('indexed_ab');
            t.dropIndex('indexed_u');
          }))
          .run(conn);
      expect(await indexes(), ['indexed_a_idx', 'indexed_b_idx']);
      // A name of neither, as of a typo, fails, rather than being recorded
      // as run.
      await expectLater(
        (PostgresSchema()..alter('indexed', (t) => t.dropIndex('indexed_ab')))
            .run(conn),
        throwsA(anything),
      );
      await conn.execute('DROP TABLE indexed');
    });

    test('changes a column of a name with quotes to a serial type', () async {
      await conn.execute('DROP TABLE IF EXISTS "o\'brien"');
      // A name with a quote, and one with the tag of the DO block.
      await conn.execute(
        'CREATE TABLE "o\'brien" (id int, "a\$sequence\$b" int)',
      );
      await (PostgresSchema()..alter('"o\'brien"', (t) {
            t.changeColumnType('id', ColumnType.serial);
            t.changeColumnType('"a\$sequence\$b"', ColumnType.bigSerial);
            t.addIndex('obrien_id', ['id'], IndexType.standardIndex);
          }))
          .run(conn);
      await conn.execute('INSERT INTO "o\'brien" DEFAULT VALUES');
      var r = await conn.execute('SELECT id, "a\$sequence\$b" FROM "o\'brien"');
      expect(r.single.toList(), [1, 1]);
      r = await conn.execute(
        "SELECT indexname FROM pg_indexes WHERE tablename = 'o''brien'",
      );
      expect(r.map((row) => row[0]), ['obrien_id']);
      await conn.execute('DROP TABLE "o\'brien"');
    });

    test('creates, alters and drops a table of another schema', () async {
      await conn.execute('DROP SCHEMA IF EXISTS audit CASCADE');
      await conn.execute('CREATE SCHEMA audit');
      try {
        await (PostgresSchema()
              ..create('audit.events', (t) {
                t.serial('id').primaryKey();
                t.float('x').defaultsTo(double.nan);
                t.integer('"Seq"');
              })
              ..indexes(
                'audit.events',
                (t) => t.addIndex('ix', ['x'], IndexType.standardIndex),
              )
              ..alter('audit.events', (t) {
                t.rename('audit.logs');
                t.changeColumnType('id', ColumnType.bigSerial);
                t.changeColumnType('"Seq"', ColumnType.serial);
                // Of its name before the rename, which keeps it.
                t.dropPrimaryIndex();
              })
              ..indexes('audit.logs', (t) => t.dropIndex('ix')))
            .run(conn);
        await conn.execute('INSERT INTO audit.logs DEFAULT VALUES');
        var r = await conn.execute(
          "SELECT id, \"Seq\", x = 'NaN' FROM audit.logs",
        );
        expect(r.single.toList(), [1, 1, true]);
        r = await conn.execute(
          "SELECT 1 FROM pg_indexes WHERE schemaname = 'audit'",
        );
        expect(r, isEmpty);
        await (PostgresSchema()..drop('audit.logs')).run(conn);
        r = await conn.execute(
          "SELECT 1 FROM information_schema.tables "
          "WHERE table_schema = 'audit'",
        );
        expect(r, isEmpty);
      } finally {
        await conn.execute('DROP SCHEMA IF EXISTS audit CASCADE');
      }
    });

    test('keeps a UTC DateTime default in UTC', () async {
      await conn.execute('DROP TABLE IF EXISTS utc_dated');
      // Not read in the time zone of the session.
      await conn.execute("SET TIME ZONE 'America/New_York'");
      await (PostgresSchema()..create('utc_dated', (t) {
            t.integer('n');
            t.timeStamp('at', timezone: true).defaultsTo(DateTime.utc(2020));
          }))
          .run(conn);
      await conn.execute('INSERT INTO utc_dated (n) VALUES (1)');
      var r = await conn.execute(
        'SELECT extract(epoch FROM at)::bigint FROM utc_dated',
      );
      expect(r.single[0], DateTime.utc(2020).millisecondsSinceEpoch ~/ 1000);
      await conn.execute('DROP TABLE utc_dated');
      await conn.execute('SET TIME ZONE DEFAULT');
    });

    test('quotes a DateTime default', () async {
      await conn.execute('DROP TABLE IF EXISTS dated');
      await (PostgresSchema()..create(
            'dated',
            (t) => t.timeStamp('at').defaultsTo(DateTime(2020, 1, 2, 3, 4, 5)),
          ))
          .run(conn);
      var r = await conn.execute(
        "SELECT column_default FROM information_schema.columns "
        "WHERE table_name = 'dated' AND column_name = 'at'",
      );
      expect(r.single[0], contains('2020-01-02 03:04:05'));
      await conn.execute('DROP TABLE dated');
    });

    test('gives a column that kept its sequence its default again', () async {
      await conn.execute('DROP TABLE IF EXISTS seq');
      await conn.execute('CREATE TABLE seq (id serial PRIMARY KEY, n int)');
      await (PostgresSchema()..alter(
            'seq',
            (t) => t.changeColumnType(
              'id',
              ColumnType.int,
              defaultValue: noDefault,
            ),
          ))
          .run(conn);
      await (PostgresSchema()
            ..alter('seq', (t) => t.changeColumnType('id', ColumnType.serial)))
          .run(conn);
      // Without an id, from the sequence.
      await conn.execute('INSERT INTO seq (n) VALUES (1)');

      // A serial type with `autoIncrement: false` is only its integer.
      await (PostgresSchema()..alter(
            'seq',
            (t) => t.changeColumnType(
              'n',
              ColumnType.bigSerial,
              autoIncrement: false,
            ),
          ))
          .run(conn);
      var r = await conn.execute(
        "SELECT data_type, column_default FROM information_schema.columns "
        "WHERE table_name = 'seq' AND column_name = 'n'",
      );
      expect(r.single.toList(), ['bigint', null]);
      await conn.execute('DROP TABLE seq');
    });

    test('throws, and does not record a migration that fails', () async {
      var failing = PostgresMigrationRunner(
        conn,
        migrations: [FailingMigration()],
      );
      // Creates the migrations table, and rolls back none.
      await failing.rollback();
      Future<Object?> count() async =>
          (await conn.execute('SELECT COUNT(*) FROM migrations')).first[0];
      var before = await count();
      await expectLater(failing.up(), throwsA(anything));
      expect(await count(), before);
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

    test('keeps what the new column can have', () async {
      await conn.query('DROP TABLE IF EXISTS kept');
      await conn.query(_keptTable);
      await (MariaDbSchema()..alter('kept', _alterKept)).run(conn);

      var rows = await conn.query(_keptColumns);
      // `mysql1` may give text as a `Blob`.
      _expectKept([
        for (var row in rows) [for (var value in row) value?.toString()],
      ]);
      await conn.query('DROP TABLE kept');
    });

    test('keeps the CHECK of a column, as that of a JSON', () async {
      await conn.query('DROP TABLE IF EXISTS checked');
      await conn.query('CREATE TABLE checked (data JSON, p int CHECK (p > 0))');
      await (MariaDbSchema()..alter('checked', (t) {
            t.setNotNull('data');
            t.changeColumnType('p', ColumnType.bigInt);
          }))
          .run(conn);

      var rows = await conn.query(
        'SELECT CONSTRAINT_NAME, CHECK_CLAUSE '
        'FROM information_schema.CHECK_CONSTRAINTS '
        "WHERE CONSTRAINT_SCHEMA = database() AND TABLE_NAME = 'checked' "
        'ORDER BY CONSTRAINT_NAME',
      );
      expect(rows.map((r) => [r[0], r[1].toString()]), [
        ['data', 'json_valid(`data`)'],
        ['p', '`p` > 0'],
      ]);
      await expectLater(
        conn.query("INSERT INTO checked (data, p) VALUES ('nope', 1)"),
        throwsA(anything),
      );
      await conn.query('DROP TABLE checked');
    });

    test('throws, and does not record a migration that fails', () async {
      var failing = MariaDbMigrationRunner(
        conn,
        migrations: [FailingMigration()],
      );
      // Creates the migrations table, and rolls back none.
      await failing.rollback();
      Future<Object?> count() async =>
          (await conn.query('SELECT COUNT(*) FROM migrations')).first[0];
      var before = await count();
      await expectLater(failing.up(), throwsA(anything));
      expect(await count(), before);
    });

    test('keeps a column INVISIBLE, and makes a key serial', () async {
      await conn.query('DROP TABLE IF EXISTS hidden');
      await conn.query(
        // An invisible column that is NOT NULL must have a default.
        'CREATE TABLE hidden (id int NOT NULL, n int, '
        'secret int DEFAULT 0 INVISIBLE, PRIMARY KEY (id))',
      );
      await (MariaDbSchema()..alter('hidden', (t) {
            t.changeColumnType('id', ColumnType.serial);
            // Not a key, so not AUTO_INCREMENT, which the database rejects.
            t.changeColumnType('n', ColumnType.serial);
            t.setNotNull('secret');
          }))
          .run(conn);

      var rows = await conn.query(
        'SELECT column_name, is_nullable, extra '
        'FROM information_schema.columns '
        "WHERE table_schema = database() AND table_name = 'hidden' "
        'ORDER BY column_name',
      );
      expect(rows.map((r) => [r[0], r[1], r[2].toString().toLowerCase()]), [
        ['id', 'NO', 'auto_increment'],
        ['n', 'YES', ''],
        ['secret', 'NO', 'invisible'],
      ]);
      await conn.query('DROP TABLE hidden');
    });

    test('creates a table of a reserved name, with a prefix index', () async {
      await conn.query('DROP TABLE IF EXISTS `order`');
      await (MariaDbSchema()
            ..create('order', (t) {
              t.text('body');
              t.timeStamp('at').defaultsTo(DateTime(2020, 1, 2, 3, 4, 5));
            })
            ..indexes(
              'order',
              (t) => t.addIndex('order_body', [
                'body(100)',
              ], IndexType.standardIndex),
            ))
          .run(conn);
      var rows = await conn.query(
        'SELECT sub_part FROM information_schema.statistics '
        "WHERE table_schema = database() AND table_name = 'order'",
      );
      expect(rows.map((r) => r[0]), [100]);
      rows = await conn.query(
        'SELECT column_default FROM information_schema.columns '
        "WHERE table_schema = database() AND table_name = 'order' "
        "AND column_name = 'at'",
      );
      expect(rows.single[0].toString(), contains('2020-01-02 03:04:05'));
      await (MariaDbSchema()..drop('order')).run(conn);
    });

    test('rolls back the migrations of a batch newest first', () async {
      await conn.query('DROP TABLE IF EXISTS children');
      await conn.query('DROP TABLE IF EXISTS parents');
      await MariaDbMigrationRunner(
        conn,
        migrations: [ParentMigration(), ChildMigration()],
      ).up();
      // Given in another order, which is not that they were run in.
      await MariaDbMigrationRunner(
        conn,
        migrations: [ChildMigration(), ParentMigration()],
      ).rollback();
      var tables = await conn.query(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = database() "
        "AND table_name IN ('parents', 'children')",
      );
      expect(tables, isEmpty);
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

    test('keeps what the new column can have', () async {
      await conn.execute('DROP TABLE IF EXISTS kept');
      await conn.execute(_keptTable);
      await (MySqlSchema()..alter('kept', _alterKept)).run(conn);

      var result = await conn.execute(_keptColumns);
      _expectKept([
        for (var row in result.rows) [for (var i = 0; i < 6; i++) row.colAt(i)],
      ]);
      await conn.execute('DROP TABLE kept');
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
