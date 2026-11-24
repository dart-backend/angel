import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';

/// The errors of PostgreSQL, as the executor classifies them.
void main() {
  late Connection conn;
  late QueryExecutor executor;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    await conn.execute(
      'CREATE TEMPORARY TABLE owners (id uuid PRIMARY KEY, '
      'email varchar UNIQUE, name varchar NOT NULL, '
      'age integer CHECK (age >= 0), code varchar(2))',
    );
    await conn.execute(
      'CREATE TEMPORARY TABLE pets (id serial PRIMARY KEY, '
      'owner_id uuid REFERENCES owners(id))',
    );
    await conn.execute(
      "INSERT INTO owners (id, email, name) VALUES "
      "('6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b', 'a@x', 'A')",
    );
  });

  tearDown(() async {
    if (conn.isOpen) await conn.close();
  });

  /// The classification of the error of [sql].
  Future<QueryError?> errorOf(String sql) async {
    try {
      await executor.query('owners', sql, {});
    } catch (e) {
      return executor.classifyError(e);
    }
    fail('No error: $sql');
  }

  test('a duplicate key, with its constraint', () async {
    var error = await errorOf(
      "INSERT INTO owners (id, email, name) VALUES "
      "('7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c', 'a@x', 'B')",
    );
    expect(error?.kind, QueryErrorKind.uniqueViolation);
    expect(error?.constraint, 'owners_email_key');
  });

  test('a NULL of a column that requires a value', () async {
    expect(
      await errorOf(
        "INSERT INTO owners (id) VALUES ('7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c')",
      ),
      const QueryError(QueryErrorKind.notNullViolation, column: 'name'),
    );
  });

  test('a foreign key', () async {
    var error = await errorOf(
      "INSERT INTO pets (owner_id) VALUES ('8b3e4c0a-5d6f-4a7b-8c1d-2e3f4a5b6c7d')",
    );
    expect(error?.kind, QueryErrorKind.foreignKeyViolation);
    expect(error?.constraint, 'pets_owner_id_fkey');
  });

  test('a malformed UUID, or text too long, is an invalid value', () async {
    expect(
      (await errorOf("SELECT * FROM owners WHERE id = 'not-a-uuid'"))?.kind,
      QueryErrorKind.invalidValue,
    );
    expect(
      (await errorOf("UPDATE owners SET code = 'abc'"))?.kind,
      QueryErrorKind.invalidValue,
    );
  });

  test('not another error', () async {
    expect(await errorOf('SELECT * FROM nowhere'), isNull);
    expect(executor.classifyError(StateError('x')), isNull);
  });
}
