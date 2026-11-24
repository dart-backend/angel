import 'package:test/test.dart';

import 'common.dart';
import 'models/profile_user.dart';

/// Fields of `@serializable` classes that are not ORM models, such as
/// `UserProfile? get profile`, are stored as JSON text (issue 118).
void main() {
  for (var backend in backends) {
    group(backend.name, () {
      late TestDatabase db;

      setUp(() async => db = await backend.open());
      tearDown(() => db.close());

      Future<ProfileUser> insert(String name, UserProfile? profile) async {
        var query = ProfileUserQuery()
          ..values.name = name
          ..values.profile = profile
          ..values.address = UserAddress(city: 'Lisbon');
        return (await query.insert(db.executor)).value;
      }

      test('a model is stored as JSON and read back', () async {
        var user = await insert(
          'ana',
          UserProfile(firstName: 'Ana', lastName: 'Silva'),
        );
        expect(user.profile, UserProfile(firstName: 'Ana', lastName: 'Silva'));
        expect(user.address, UserAddress(city: 'Lisbon'));

        var read = await (ProfileUserQuery()..where!.name.equals('ana'))
            .getOne(db.executor);
        expect(
          read.value.profile,
          UserProfile(firstName: 'Ana', lastName: 'Silva'),
        );
        expect(read.value.address, UserAddress(city: 'Lisbon'));
      });

      test('its column is TEXT, of a JSON object', () async {
        var columns = await db.select("PRAGMA table_info('profile_users')");
        String typeOf(String name) =>
            columns.firstWhere((c) => c['name'] == name)['type'] as String;
        expect(typeOf('profile'), 'TEXT');
        expect(typeOf('address'), 'TEXT');

        await insert('ana', UserProfile(firstName: 'Ana', lastName: 'Silva'));
        var rows = await db.select(
          'SELECT typeof(profile) AS type, json_type(profile) AS json, '
          "json_extract(profile, '\$.first_name') AS first_name "
          'FROM profile_users',
        );
        expect(rows.single, {
          'type': 'text',
          'json': 'object',
          'first_name': 'Ana',
        });
      });

      test('a null model is stored as NULL', () async {
        var user = await insert('bo', null);
        expect(user.profile, isNull);
        var rows = await db.select(
          'SELECT profile IS NULL AS absent FROM profile_users',
        );
        expect(rows.single['absent'], 1);

        var read = await (ProfileUserQuery()..where!.name.equals('bo'))
            .getOne(db.executor);
        expect(read.value.profile, isNull);
      });

      test('it may be queried as a map', () async {
        await insert('ana', UserProfile(firstName: 'Ana', lastName: 'Silva'));
        await insert('bo', UserProfile(firstName: 'Bo', lastName: 'Berg'));
        var query = ProfileUserQuery()
          ..where!.profile['first_name'].asString?.equals('Bo');
        var users = await query.get(db.executor);
        expect(users.map((u) => u.name), ['bo']);
      });

      test('an update replaces it', () async {
        var user = await insert(
          'ana',
          UserProfile(firstName: 'Ana', lastName: 'Silva'),
        );
        var query = ProfileUserQuery()
          ..where!.id.equals(int.parse(user.id!))
          ..values.profile = UserProfile(firstName: 'Ana', lastName: 'Costa');
        var updated = await query.updateOne(db.executor);
        expect(updated.value.profile?.lastName, 'Costa');

        var read = await (ProfileUserQuery()..where!.name.equals('ana'))
            .getOne(db.executor);
        expect(read.value.profile?.lastName, 'Costa');
      });
    });
  }
}
