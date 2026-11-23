import 'package:test/test.dart';

import 'common.dart';
import 'models/uuid_user.dart';

const ana = '6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b';
const bo = '7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c';
const cy = '8b3e4c0a-5d6f-4a7b-8c1d-2e3f4a5b6c7d';
const staff = '9c4f5d1b-6e7a-4b8c-9d2e-3f4a5b6c7d8e';
const admins = 'ad5a6e2c-7f8b-4c9d-8e3f-4a5b6c7d8e9f';

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

      Future<UuidTag> tag(String name) async =>
          (await (UuidTagQuery()..values.name = name).insert(db.executor))
              .value;

      Future<UuidGroup> group(String id, String name) async =>
          (await (UuidGroupQuery()
                    ..values.id = id
                    ..values.name = name)
                  .insert(db.executor))
              .value;

      Future<void> tagUser(String userId, UuidTag tag) =>
          (UuidUserTagQuery()
                ..values.uuidUserId = userId
                ..values.uuidTagId = int.parse(tag.id!))
              .insert(db.executor);

      Future<void> addToGroup(String userId, String groupId) =>
          (UuidUserGroupQuery()
                ..values.uuidUserId = userId
                ..values.uuidGroupId = groupId)
              .insert(db.executor);

      test(
        'the keys of the pivots are of the types of those they refer to',
        () async {
          String typeOf(List<Map<String, Object?>> columns, String name) =>
              columns.firstWhere((c) => c['name'] == name)['type'] as String;
          var tags = await db.select("PRAGMA table_info('uuid_user_tags')");
          var groups = await db.select("PRAGMA table_info('uuid_user_groups')");
          expect(typeOf(tags, 'uuid_user_id'), 'TEXT');
          expect(typeOf(tags, 'uuid_tag_id'), contains('INT'));
          expect(typeOf(groups, 'uuid_user_id'), 'TEXT');
          expect(typeOf(groups, 'uuid_group_id'), 'TEXT');
        },
      );

      test('many-to-many of a UUID and an integer id', () async {
        await user(ana, 'Ana');
        await user(bo, 'Bo');
        await user(cy, 'Cy');
        var red = await tag('red'), blue = await tag('blue');
        await tagUser(ana, red);
        await tagUser(ana, blue);
        await tagUser(bo, red);

        var users = {
          for (var u in await UuidUserQuery().get(db.executor))
            u.id: {for (var t in u.tags) t.name},
        };
        expect(users, {
          ana: {'red', 'blue'},
          bo: {'red'},
          cy: <String>{},
        });

        var tags = {
          for (var t in await UuidTagQuery().get(db.executor))
            t.name: {for (var u in t.users) u.id},
        };
        expect(tags, {
          'red': {ana, bo},
          'blue': {ana},
        });
      });

      test('many-to-many of two UUIDs', () async {
        await user(ana, 'Ana');
        await user(bo, 'Bo');
        await group(staff, 'Staff');
        await group(admins, 'Admins');
        await addToGroup(ana, staff);
        await addToGroup(ana, admins);
        await addToGroup(bo, staff);

        var read = await (UuidUserQuery()..where!.id.equals(ana)).getOne(
          db.executor,
        );
        expect(read.value.groups.map((g) => g.id).toSet(), {staff, admins});

        var groups = {
          for (var g in await UuidGroupQuery().get(db.executor))
            g.id: {for (var u in g.users) u.id},
        };
        expect(groups, {
          staff: {ana, bo},
          admins: {ana},
        });
      });
    });
  }
}
