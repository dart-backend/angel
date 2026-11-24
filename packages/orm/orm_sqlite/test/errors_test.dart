import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_sqlite/angel3_orm_sqlite.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import 'package:test/test.dart';

import 'common.dart';

/// The errors of SQLite, as the executors classify them.
void main() {
  for (var backend in backends) {
    group(backend.name, () {
      late TestDatabase db;

      setUp(() async {
        db = await backend.open();
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute(
          'CREATE TABLE owners (id TEXT PRIMARY KEY NOT NULL, '
          'email TEXT UNIQUE, name TEXT NOT NULL, '
          'age INTEGER CHECK (age >= 0))',
        );
        await db.execute(
          'CREATE TABLE pets (id INTEGER PRIMARY KEY, '
          'owner_id TEXT REFERENCES owners(id))',
        );
        await db.execute(
          'CREATE TABLE keys (tenant_id INTEGER, email TEXT, '
          '"first name" TEXT UNIQUE, '
          'price REAL CONSTRAINT positive_price CHECK (price > 0), '
          'ratio REAL CHECK (0.5 < ratio), '
          'UNIQUE (tenant_id, email))',
        );
        await db.execute(
          'CREATE UNIQUE INDEX lower_email ON keys(lower(email)) WHERE tenant_id = 2',
        );
        await db.execute('CREATE TABLE strict (n INTEGER) STRICT');
        await db.execute('CREATE TABLE plain (b INTEGER)');
        await db.execute(
          'CREATE TABLE odd (active INTEGER CHECK (active), '
          'z INTEGER, "x, y" TEXT UNIQUE, '
          'CONSTRAINT "pos z" CHECK (z > 0))',
        );
        await db.execute('CREATE TABLE "my.t" (a INTEGER UNIQUE)');
        await db.execute('CREATE TABLE "my.s" (n INTEGER) STRICT');
        await db.execute("INSERT INTO odd (\"x, y\") VALUES ('v')");
        await db.execute('INSERT INTO "my.t" (a) VALUES (1)');
        await db.execute(
          "INSERT INTO keys (tenant_id, email, \"first name\") VALUES (1, 'a@x', 'Ann')",
        );
        await db.execute(
          "INSERT INTO keys (tenant_id, email) VALUES (2, 'b@x')",
        );
        await db.execute('INSERT INTO plain (rowid, b) VALUES (1, 1)');
        await db.execute(
          "INSERT INTO owners (id, email, name) VALUES ('a', 'a@x', 'A')",
        );
      });
      tearDown(() => db.close());

      /// The classification of the error of [sql], a statement of [table].
      Future<QueryError?> errorOf(String sql, [String table = 'owners']) async {
        try {
          await db.executor.query(table, sql, {});
        } catch (e) {
          return db.executor.classifyError(e);
        }
        fail('No error: $sql');
      }

      test('a duplicate primary key, or unique value', () async {
        expect(
          await errorOf("INSERT INTO owners (id, name) VALUES ('a', 'B')"),
          const QueryError(QueryErrorKind.uniqueViolation, column: 'id'),
        );
        expect(
          await errorOf(
            "INSERT INTO owners (id, email, name) VALUES ('b', 'a@x', 'B')",
          ),
          const QueryError(QueryErrorKind.uniqueViolation, column: 'email'),
        );
      });

      test('a NULL of a column that requires a value', () async {
        expect(
          await errorOf("INSERT INTO owners (id) VALUES ('b')"),
          const QueryError(QueryErrorKind.notNullViolation, column: 'name'),
        );
      });

      test('a foreign key', () async {
        expect(
          (await errorOf("INSERT INTO pets (owner_id) VALUES ('nobody')"))
              ?.kind,
          QueryErrorKind.foreignKeyViolation,
        );
      });

      test('a value a CHECK refuses', () async {
        expect(
          (await errorOf(
            "INSERT INTO owners (id, name, age) VALUES ('b', 'B', -1)",
          ))?.kind,
          QueryErrorKind.invalidValue,
        );
      });

      test('a duplicate key of several columns', () async {
        expect(
          await errorOf(
            "INSERT INTO keys (tenant_id, email) VALUES (1, 'a@x')",
            'keys',
          ),
          const QueryError(QueryErrorKind.uniqueViolation),
        );
      });

      test('a duplicate of a unique index on an expression', () async {
        expect(
          await errorOf(
            "INSERT INTO keys (tenant_id, email) VALUES (2, 'B@x')",
            'keys',
          ),
          const QueryError(
            QueryErrorKind.uniqueViolation,
            constraint: 'lower_email',
          ),
        );
      });

      test('a duplicate of a column whose name has a space', () async {
        expect(
          await errorOf(
            'INSERT INTO keys ("first name") VALUES (\'Ann\')',
            'keys',
          ),
          const QueryError(
            QueryErrorKind.uniqueViolation,
            column: 'first name',
          ),
        );
      });

      test('a duplicate rowid', () async {
        expect(
          await errorOf('INSERT INTO plain (rowid, b) VALUES (1, 2)', 'plain'),
          const QueryError(QueryErrorKind.uniqueViolation),
        );
      });

      test('a CHECK of a name, and of none', () async {
        expect(
          await errorOf('INSERT INTO keys (price) VALUES (-1)', 'keys'),
          const QueryError(
            QueryErrorKind.invalidValue,
            constraint: 'positive_price',
          ),
        );
        expect(
          await errorOf('INSERT INTO keys (ratio) VALUES (0)', 'keys'),
          const QueryError(QueryErrorKind.invalidValue),
        );
      });

      test('a value of the wrong type in a STRICT table', () async {
        expect(
          await errorOf("INSERT INTO strict (n) VALUES ('abc')", 'strict'),
          const QueryError(QueryErrorKind.invalidValue, column: 'n'),
        );
      });

      test('a CHECK of a bare column, and of a quoted name', () async {
        expect(
          await errorOf('INSERT INTO odd (active) VALUES (0)', 'odd'),
          const QueryError(QueryErrorKind.invalidValue),
        );
        expect(
          await errorOf('INSERT INTO odd (z) VALUES (0)', 'odd'),
          const QueryError(QueryErrorKind.invalidValue, constraint: 'pos z'),
        );
      });

      test('a column whose name has a comma', () async {
        expect(
          await errorOf("INSERT INTO odd (\"x, y\") VALUES ('v')", 'odd'),
          const QueryError(QueryErrorKind.uniqueViolation, column: 'x, y'),
        );
      });

      test('a table whose name has a dot', () async {
        expect(
          await errorOf('INSERT INTO "my.t" (a) VALUES (1)', 'my.t'),
          const QueryError(QueryErrorKind.uniqueViolation, column: 'a'),
        );
        expect(
          await errorOf('INSERT INTO "my.s" (n) VALUES (\'abc\')', 'my.s'),
          const QueryError(QueryErrorKind.invalidValue, column: 'n'),
        );
      });

      test('in a transaction', () async {
        await db.executor.transaction((tx) async {
          try {
            await tx.query('odd', 'INSERT INTO odd (z) VALUES (0)', {});
            fail('No error');
          } catch (e) {
            expect(
              tx.classifyError(e),
              const QueryError(
                QueryErrorKind.invalidValue,
                constraint: 'pos z',
              ),
            );
          }
        });
      });

      test('not another error', () async {
        expect(await errorOf('SELECT * FROM nowhere'), isNull);
        expect(db.executor.classifyError(StateError('x')), isNull);
      });
    });
  }

  group('an error not of an executor', () {
    QueryError? of(int code, String message) => classifySqliteError(
      SqliteException(extendedResultCode: code, message: message),
    );

    test('reads a column up to the first dot', () {
      expect(
        of(2067, 'UNIQUE constraint failed: users.email'),
        const QueryError(QueryErrorKind.uniqueViolation, column: 'email'),
      );
      expect(
        of(2067, 'UNIQUE constraint failed: t.a, t.b'),
        const QueryError(QueryErrorKind.uniqueViolation),
      );
      expect(
        of(3091, 'cannot store TEXT value in INTEGER column s.n'),
        const QueryError(QueryErrorKind.invalidValue, column: 'n'),
      );
    });

    test('names no CHECK', () {
      expect(
        of(275, 'CHECK constraint failed: positive_price'),
        const QueryError(QueryErrorKind.invalidValue),
      );
    });
  });
}
