import 'package:test/test.dart';

import 'common.dart';
import 'models/uuid_user.dart';

const ana = '6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b';
const bo = '7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c';

/// A `Model` whose `id` is a UUID, as text (issue 91), related to one of an
/// integer `id`.
void main() {
  for (var backend in backends) {
    group(backend.name, () {
      late TestDatabase db;

      setUp(() async => db = await backend.open());
      tearDown(() => db.close());

      Future<UuidUser> user(String id, String name) async =>
          (await (UuidUserQuery()
                    ..values.id = id
                    ..values.name = name)
                  .insert(db.executor))
              .value;

      Future<UuidPost> post(String authorId, String title) async =>
          (await (UuidPostQuery()
                    ..values.authorId = authorId
                    ..values.title = title)
                  .insert(db.executor))
              .value;

      test('the columns are of the types declared', () async {
        var users = await db.select("PRAGMA table_info('uuid_users')");
        var posts = await db.select("PRAGMA table_info('uuid_posts')");
        String typeOf(List<Map<String, Object?>> columns, String name) =>
            columns.firstWhere((c) => c['name'] == name)['type'] as String;
        expect(typeOf(users, 'id'), 'TEXT');
        expect(typeOf(posts, 'author_id'), 'TEXT');
        expect(typeOf(posts, 'id'), contains('INTEGER'));
      });

      test('an insert, a query by id, an update and a delete', () async {
        expect((await user(ana, 'Ana')).id, ana);
        await user(bo, 'Bo');
        var read = await (UuidUserQuery()..where!.id.equals(bo)).getOne(
          db.executor,
        );
        expect(read.value.name, 'Bo');
        var updated =
            await (UuidUserQuery()
                  ..where!.id.equals(ana)
                  ..values.name = 'Ana Maria')
                .updateOne(db.executor);
        expect(updated.value.name, 'Ana Maria');
        await (UuidUserQuery()..where!.id.equals(bo)).deleteOne(db.executor);
        expect((await UuidUserQuery().get(db.executor)).map((u) => u.id), [
          ana,
        ]);
      });

      test('belongs to, and has many, of a UUID', () async {
        await user(ana, 'Ana');
        var p = await post(ana, 'One');
        await post(ana, 'Two');
        expect(int.tryParse(p.id!), isNotNull);
        expect(p.author?.name, 'Ana');
        var read = await (UuidUserQuery()..where!.id.equals(ana)).getOne(
          db.executor,
        );
        expect(read.value.posts.map((p) => p.title).toSet(), {'One', 'Two'});
      });
    });
  }
}
