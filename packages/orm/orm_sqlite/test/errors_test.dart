import 'package:angel3_orm/angel3_orm.dart';
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
          "INSERT INTO owners (id, email, name) VALUES ('a', 'a@x', 'A')",
        );
      });
      tearDown(() => db.close());

      /// The classification of the error of [sql].
      Future<QueryError?> errorOf(String sql) async {
        try {
          await db.executor.query('owners', sql, {});
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

      test('not another error', () async {
        expect(await errorOf('SELECT * FROM nowhere'), isNull);
        expect(db.executor.classifyError(StateError('x')), isNull);
      });
    });
  }
}
