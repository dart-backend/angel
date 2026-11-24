import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';

/// The errors of MySQL and MariaDB, as the executor classifies them.
void main() {
  late MySQLConnection conn;
  late QueryExecutor executor;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    await conn.execute('DROP TABLE IF EXISTS err_pets');
    await conn.execute('DROP TABLE IF EXISTS err_owners');
    await conn.execute(
      'CREATE TABLE err_owners (id char(36) PRIMARY KEY, '
      'email varchar(64) UNIQUE, name varchar(64) NOT NULL, '
      'age int, code varchar(2))',
    );
    await conn.execute(
      'CREATE TABLE err_pets (id int AUTO_INCREMENT PRIMARY KEY, '
      'owner_id char(36), CONSTRAINT err_pets_owner '
      'FOREIGN KEY (owner_id) REFERENCES err_owners(id))',
    );
    await conn.execute(
      "INSERT INTO err_owners (id, email, name) VALUES ('a', 'a@x', 'A')",
    );
  });

  tearDown(() async {
    await conn.execute('DROP TABLE IF EXISTS err_pets');
    await conn.execute('DROP TABLE IF EXISTS err_owners');
    if (conn.connected) await conn.close();
  });

  /// The classification of the error of [sql].
  Future<QueryError?> errorOf(String sql) async {
    try {
      await executor.query('err_owners', sql, {});
    } catch (e) {
      return executor.classifyError(e);
    }
    fail('No error: $sql');
  }

  test('a duplicate key, with its key', () async {
    var error = await errorOf(
      "INSERT INTO err_owners (id, email, name) VALUES ('b', 'a@x', 'B')",
    );
    expect(error?.kind, QueryErrorKind.uniqueViolation);
    expect(error?.constraint, contains('email'));
  });

  test('a NULL of a column that requires a value', () async {
    expect(
      await errorOf("INSERT INTO err_owners (id, name) VALUES ('b', NULL)"),
      const QueryError(QueryErrorKind.notNullViolation, column: 'name'),
    );
  });

  test('a foreign key, with its constraint', () async {
    var error = await errorOf(
      "INSERT INTO err_pets (owner_id) VALUES ('nobody')",
    );
    expect(error?.kind, QueryErrorKind.foreignKeyViolation);
    expect(error?.constraint, 'err_pets_owner');
  });

  test('text too long, or not a number, is an invalid value', () async {
    expect(
      await errorOf("UPDATE err_owners SET code = 'abc'"),
      const QueryError(QueryErrorKind.invalidValue, column: 'code'),
    );
    expect(
      (await errorOf("UPDATE err_owners SET age = 'old'"))?.kind,
      QueryErrorKind.invalidValue,
    );
  });

  test('not another error', () async {
    expect(await errorOf('SELECT * FROM nowhere'), isNull);
    expect(executor.classifyError(StateError('x')), isNull);
  });
}
