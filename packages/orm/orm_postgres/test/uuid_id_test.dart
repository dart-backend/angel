import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/uuid_user.dart';

const ana = '6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b';
const bo = '7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c';

/// A `Model` whose `id` is a UUID (issue 91), related to one of an integer
/// `id`.
void main() {
  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      UuidUserMigration(),
      UuidPostMigration(),
    ]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) await conn.close();
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
      "SELECT table_name, column_name, data_type FROM information_schema.columns "
      "WHERE table_name IN ('uuid_users', 'uuid_posts') "
      "AND column_name IN ('id', 'author_id') ORDER BY 1, 2",
    );
    expect(result.map((r) => r.toList()), [
      ['uuid_posts', 'author_id', 'uuid'],
      ['uuid_posts', 'id', 'integer'],
      ['uuid_users', 'id', 'uuid'],
    ]);
  });

  test('an insert of a given id returns it', () async {
    var u = await user(ana, 'Ana');
    expect(u.id, ana);
    expect(u.name, 'Ana');
    expect(u.createdAt, isNull);
  });

  test('a query by id, update and delete', () async {
    await user(ana, 'Ana');
    await user(bo, 'Bo');
    var read = await (UuidUserQuery()..where!.id.equals(bo)).getOne(executor);
    expect(read.value.name, 'Bo');

    var updated =
        await (UuidUserQuery()
              ..where!.id.equals(ana)
              ..values.name = 'Ana Maria')
            .updateOne(executor);
    expect(updated.value.name, 'Ana Maria');

    var deleted = await (UuidUserQuery()..where!.id.equals(bo)).deleteOne(
      executor,
    );
    expect(deleted.value.id, bo);
    expect((await UuidUserQuery().get(executor)).map((u) => u.id), [ana]);
  });

  test('a model of an integer id belongs to one of a UUID', () async {
    await user(ana, 'Ana');
    var p = await post(ana, 'Hello');
    expect(int.tryParse(p.id!), isNotNull);
    expect(p.author?.id, ana);
    expect(p.author?.name, 'Ana');

    var byAuthor = await (UuidPostQuery()..where!.authorId.equals(ana)).get(
      executor,
    );
    expect(byAuthor.map((p) => p.title), ['Hello']);
  });

  test('a model of a UUID has many of an integer id', () async {
    await user(ana, 'Ana');
    await user(bo, 'Bo');
    await post(ana, 'One');
    await post(ana, 'Two');
    await post(bo, 'Three');
    var read = await (UuidUserQuery()..where!.id.equals(ana)).getOne(executor);
    expect(read.value.posts.map((p) => p.title).toSet(), {'One', 'Two'});
  });

  test('copyFrom sets the id, and the key of a relation', () async {
    var values = UuidPostQueryValues()
      ..copyFrom(
        UuidPost(
          title: 'T',
          author: UuidUser(id: ana, name: 'Ana'),
        ),
      );
    expect(values.authorId, ana);
    var userValues = UuidUserQueryValues()..copyFrom(UuidUser(id: bo));
    expect(userValues.id, bo);
  });
}
