import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/sqlite.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'models/pg_todo.dart';

/// A migration of [up] and [down].
class _Migration extends Migration {
  final void Function(Schema) _up, _down;
  final String _name;

  _Migration(this._name, this._up, [void Function(Schema)? down])
    : _down = down ?? ((_) {});

  @override
  String get name => _name;

  @override
  void up(Schema schema) => _up(schema);

  @override
  void down(Schema schema) => _down(schema);
}

void main() {
  late Database db;

  setUp(() => db = sqlite3.openInMemory()..execute('PRAGMA foreign_keys = ON'));
  tearDown(() => db.close());

  SqliteMigrationRunner runnerOf(List<Migration> migrations) =>
      SqliteMigrationRunner(db, migrations: migrations);

  Set<String> tables() => {
    for (var row in db.select(
      "SELECT name FROM sqlite_schema WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name <> 'migrations'",
    ))
      row['name'] as String,
  };

  Set<String> indexes(String table) => {
    for (var row in db.select(
      "SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = ? "
      "AND name NOT LIKE 'sqlite_autoindex%'",
      [table],
    ))
      row['name'] as String,
  };

  List<String> columns(String table) => [
    for (var row in db.select('PRAGMA table_info("$table")'))
      row['name'] as String,
  ];

  List<String> recorded() => [
    for (var row in db.select('SELECT path FROM migrations ORDER BY id'))
      row['path'] as String,
  ];

  String compileUp(void Function(Schema) up) {
    var schema = SqliteSchema();
    up(schema);
    return schema.compile();
  }

  group('runner', () {
    List<Migration> migrations() => [
      CarMigration(),
      UserMigration(),
      TodoMigration(),
      ItemMigration(),
    ];

    test('up creates the tables and records them', () async {
      await runnerOf(migrations()).up();
      expect(tables(), {'cars', 'users', 'todos', 'items'});
      expect(recorded(), [
        'CarMigration',
        'UserMigration',
        'TodoMigration',
        'ItemMigration',
      ]);
      // Again, nothing to run.
      await runnerOf(migrations()).up();
      expect(recorded(), hasLength(4));
    });

    test('reset drops the tables, newest first', () async {
      await runnerOf(migrations()).up();
      await runnerOf(migrations()).reset();
      expect(tables(), isEmpty);
      expect(recorded(), isEmpty);
    });

    test('rollback undoes the last batch only', () async {
      await runnerOf([CarMigration()]).up();
      await runnerOf([CarMigration(), UserMigration()]).up();
      await runnerOf([CarMigration(), UserMigration()]).rollback();
      expect(tables(), {'cars'});
      expect(recorded(), ['CarMigration']);
    });

    test('a migration that fails is neither run nor recorded', () async {
      var failing = _Migration('Failing', (schema) {
        schema.create('first', (t) => t.integer('a'));
        schema.create('first', (t) => t.integer('a'));
      });
      await expectLater(runnerOf([failing]).up(), throwsA(isA<Exception>()));
      expect(tables(), isEmpty);
      expect(recorded(), isEmpty);
      expect(db.autocommit, isTrue);
    });

    test('runs in a transaction the database is in', () async {
      db.execute('BEGIN');
      await runnerOf([CarMigration()]).up();
      db.execute('ROLLBACK');
      expect(tables(), isEmpty);
    });

    test('gives a serial primary key, defaults and references', () async {
      await runnerOf(migrations()).up();
      db.execute("INSERT INTO users (username, password) VALUES ('a', 'p')");
      db.execute("INSERT INTO users (username, password) VALUES ('b', 'p')");
      var users = db.select('SELECT id, account_confirmed FROM users');
      expect(users.map((r) => r['id']), [1, 2]);
      expect(users.first['account_confirmed'], 0);
      expect(
        () => db.execute("INSERT INTO users (username) VALUES ('a')"),
        throwsA(isA<SqliteException>()),
        reason: 'username is unique',
      );

      db.execute("INSERT INTO todos (user_id, text) VALUES (1, 'x')");
      db.execute('DELETE FROM users WHERE id = 1');
      expect(db.select('SELECT * FROM todos'), isEmpty, reason: 'cascade');

      db.execute("INSERT INTO items (name) VALUES ('i')");
      var createdAt = db
          .select('SELECT created_at FROM items')
          .single['created_at'];
      expect(
        createdAt,
        matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{6}Z$')),
      );
      var parsed = DateTime.parse(createdAt as String);
      expect(parsed.isUtc, isTrue);
      expect(
        DateTime.now().toUtc().difference(parsed).inMinutes.abs(),
        lessThan(1),
      );
    });
  });

  group('create', () {
    test('maps the types to SQLite affinities', () {
      var sql = compileUp(
        (s) => s.create('t', (t) {
          t.serial('id').primaryKey();
          t.integer('n');
          t.declare('big', ColumnType.bigInt);
          t.double('d');
          t.numeric('price', precision: 10, scale: 2);
          t.boolean('b');
          t.timeStamp('at').notNull();
          t.varChar('name', length: 32);
          t.declare('data', ColumnType.jsonb);
          t.declare('bytes', ColumnType.varBinary);
          t.date('day').defaultsTo(DateTime.utc(2024, 3, 10, 1, 2, 3));
        }),
      );
      expect(sql, '''
CREATE TABLE "t" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "n" INTEGER,
  "big" INTEGER,
  "d" REAL,
  "price" NUMERIC(10, 2),
  "b" BOOLEAN,
  "at" TEXT NOT NULL,
  "name" VARCHAR(32),
  "data" TEXT,
  "bytes" BLOB,
  "day" TEXT DEFAULT '2024-03-10 01:02:03.000000Z'
);
''');
    });

    test('creates the index of a column with a standard index', () async {
      await runnerOf([
        _Migration('Indexed', (s) {
          s.create('people', (t) {
            t.serial('id').primaryKey();
            t.declareColumn(
              'email',
              MigrationColumn(
                ColumnType.varChar,
                indexType: IndexType.standardIndex,
              ),
            );
          });
        }),
      ]).up();
      expect(indexes('people'), {'people_email_idx'});
    });

    test('throws for a serial that is not a primary key', () {
      expect(
        () => compileUp((s) => s.create('t', (t) => t.serial('n'))),
        throwsUnsupportedError,
      );
    });
  });

  group('alter', () {
    Future<void> run(void Function(Schema) up) async {
      await runnerOf([
        _Migration(
          'Create',
          (s) => s.create('people', (t) {
            t.serial('id').primaryKey();
            t.varChar('name');
            t.varChar('old');
          }),
        ),
        _Migration('Alter', up),
      ]).up();
    }

    test('adds, renames and drops columns, and renames the table', () async {
      await run(
        (s) => s.alter('people', (t) {
          t.integer('age').notNull().defaultsTo(0);
          t.varChar('email').unique();
          t.renameColumn('name', 'full_name');
          t.dropColumn('old');
          t.rename('persons');
          t.declareColumn(
            'nick',
            MigrationColumn(
              ColumnType.varChar,
              indexType: IndexType.standardIndex,
            ),
          );
        }),
      );
      expect(tables(), {'persons'});
      expect(columns('persons'), ['id', 'full_name', 'age', 'email', 'nick']);
      expect(indexes('persons'), {'people_email_key', 'persons_nick_idx'});
      db.execute("INSERT INTO persons (email) VALUES ('a')");
      expect(db.select('SELECT age FROM persons').single['age'], 0);
      expect(
        () => db.execute("INSERT INTO persons (email) VALUES ('a')"),
        throwsA(isA<SqliteException>()),
        reason: 'email is unique',
      );
    });

    test('adds and drops indexes', () async {
      await run(
        (s) => s
          ..alter(
            'people',
            (t) => t.addIndex('by_name', ['name'], IndexType.unique),
          )
          ..indexes('people', (i) {
            i.addIndex('by_old', ['old DESC'], IndexType.standardIndex);
          }),
      );
      expect(indexes('people'), {'by_name', 'by_old'});
      await runnerOf([
        _Migration(
          'Drop',
          (s) => s
            ..alter('people', (t) => t.dropIndex('by_name'))
            ..indexes('people', (i) => i.dropIndex('by_old')),
        ),
      ]).up();
      expect(indexes('people'), isEmpty);
    });

    test('throws for the changes SQLite makes only by a new table', () {
      for (var change in <void Function(MutableTable)>[
        (t) => t.changeColumnType('name', ColumnType.text),
        (t) => t.setNotNull('name'),
        (t) => t.dropNotNull('name'),
        (t) => t.dropPrimaryIndex(),
        (t) => t.addIndex('pk', ['id'], IndexType.primaryKey),
      ]) {
        expect(
          () => compileUp((s) => s.alter('people', change)),
          throwsUnsupportedError,
        );
      }
    });

    test('throws for a primary key column added', () {
      expect(
        () => compileUp(
          (s) => s.alter('people', (t) => t.integer('k').primaryKey()),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
