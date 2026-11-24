import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/profile_user.dart';

/// Fields of `@serializable` classes that are not ORM models, such as
/// `UserProfile? get profile`, are stored as JSON, in a `json` column (issue 118).
void main() {
  late MySQLConnection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [ProfileUserMigration()]);
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.connected) await conn.close();
  });

  Future<ProfileUser> insert(String name, UserProfile? profile) async {
    var query = ProfileUserQuery()
      ..values.name = name
      ..values.profile = profile
      ..values.address = UserAddress(city: 'Lisbon');
    return (await query.insert(executor)).value;
  }

  test('a model is stored as JSON and read back', () async {
    var user = await insert(
      'ana',
      UserProfile(firstName: 'Ana', lastName: 'Silva'),
    );
    expect(user.profile, UserProfile(firstName: 'Ana', lastName: 'Silva'));
    expect(user.address, UserAddress(city: 'Lisbon'));

    var read = await (ProfileUserQuery()..where!.name.equals('ana')).getOne(
      executor,
    );
    expect(
      read.value.profile,
      UserProfile(firstName: 'Ana', lastName: 'Silva'),
    );
  });

  test('its column is json, of an object', () async {
    await insert('ana', UserProfile(firstName: 'Ana', lastName: 'Silva'));
    var result = await conn.execute(
      "SELECT JSON_TYPE(profile) AS type, "
      "JSON_UNQUOTE(JSON_EXTRACT(profile, '\$.first_name')) AS first_name "
      'FROM profile_users',
    );
    var row = result.rows.single;
    expect([row.colByName('type'), row.colByName('first_name')], [
      'OBJECT',
      'Ana',
    ]);
  });

  test('a null model is stored as NULL', () async {
    var user = await insert('bo', null);
    expect(user.profile, isNull);
    var result = await conn.execute(
      'SELECT profile IS NULL AS absent FROM profile_users',
    );
    expect(result.rows.single.colByName('absent'), '1');
  });

  test('it may be queried as a map', () async {
    await insert('ana', UserProfile(firstName: 'Ana', lastName: 'Silva'));
    await insert('bo', UserProfile(firstName: 'Bo', lastName: 'Berg'));
    var query = ProfileUserQuery()
      ..where!.profile['first_name'].asString?.equals('Bo');
    var users = await query.get(executor);
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
    var updated = await query.updateOne(executor);
    expect(updated.value.profile?.lastName, 'Costa');
  });

  test('values reads back the model it was given', () {
    var values = ProfileUserQueryValues()
      ..profile = UserProfile(firstName: 'Ana', lastName: 'Silva');
    expect(values.profile, UserProfile(firstName: 'Ana', lastName: 'Silva'));
    expect(values.toMap()['profile'], {
      'first_name': 'Ana',
      'last_name': 'Silva',
    });
    values.profile = null;
    expect(values.profile, isNull);
  });
}
