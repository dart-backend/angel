import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/uuid_user.dart';

const ana = '6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b';
const bo = '7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c';

/// A `Model` whose `id` is a UUID in `CHAR(36)` (issue 91), related to one
/// of an integer `id`.
void main() {
  late MySQLConnection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      UuidUserMigration(),
      UuidPostMigration(),
    ]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.connected) await conn.close();
  });

  Future<UuidUser> user(String id, String name) async =>
      (await (UuidUserQuery()
                ..values.id = id
                ..values.name = name)
              .insert(executor))
          .value;

  Future<UuidPost> post(String authorId, String title) async =>
      (await (UuidPostQuery()
                ..values.authorId = authorId
                ..values.title = title)
              .insert(executor))
          .value;

  test('the columns are of the types declared', () async {
    var result = await conn.execute(
      'SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH '
      'FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() '
      "AND TABLE_NAME IN ('uuid_users', 'uuid_posts') "
      "AND COLUMN_NAME IN ('id', 'author_id') ORDER BY 1, 2",
    );
    expect(
      [
        for (var row in result.rows)
          [for (var i = 0; i < 4; i++) row.colAt(i)?.toString().toLowerCase()],
      ],
      [
        ['uuid_posts', 'author_id', 'char', '36'],
        ['uuid_posts', 'id', 'int', null],
        ['uuid_users', 'id', 'char', '36'],
      ],
    );
  });

  test('an insert, a query by id, an update and a delete', () async {
    expect((await user(ana, 'Ana')).id, ana);
    await user(bo, 'Bo');
    var read = await (UuidUserQuery()..where!.id.equals(bo)).getOne(executor);
    expect(read.value.name, 'Bo');
    var updated =
        await (UuidUserQuery()
              ..where!.id.equals(ana)
              ..values.name = 'Ana Maria')
            .updateOne(executor);
    expect(updated.value.name, 'Ana Maria');
    await (UuidUserQuery()..where!.id.equals(bo)).deleteOne(executor);
    expect((await UuidUserQuery().get(executor)).map((u) => u.id), [ana]);
  });

  test('belongs to, and has many, of a UUID', () async {
    await user(ana, 'Ana');
    var p = await post(ana, 'One');
    await post(ana, 'Two');
    expect(int.tryParse(p.id!), isNotNull);
    expect(p.author?.name, 'Ana');
    var read = await (UuidUserQuery()..where!.id.equals(ana)).getOne(executor);
    expect(read.value.posts.map((p) => p.title).toSet(), {'One', 'Two'});
  });
}
