import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/relation_keys.dart';

/// Relations whose keys and tables the generator has to work out.
void main() {
  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;
  late UserIdentity main, backup;
  late Login login;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      UserIdentityMigration(),
      LoginMigration(),
      GrantMigration(),
      LoginGrantMigration(),
    ]);

    Future<UserIdentity> identity(String handle) async =>
        (await (UserIdentityQuery()..values.handle = handle).insert(executor))
            .value;
    main = await identity('main');
    backup = await identity('backup');

    login =
        (await (LoginQuery()
                  ..values.name = 'alice'
                  ..values.userIdentityId = int.parse(main.id!)
                  ..values.backupIdentityId = int.parse(backup.id!))
                .insert(executor))
            .value;

    var grant = (await (GrantQuery()..values.name = 'publish').insert(executor))
        .value;
    await (LoginGrantQuery()
          ..values.loginId = int.parse(login.id!)
          ..values.grantId = int.parse(grant.id!))
        .insert(executor);
  });

  tearDown(() async {
    await dropTables(runner);
    await conn.close();
  });

  test('a relation column with "Id" inside its name can be queried', () async {
    var query = LoginQuery()..where!.userIdentityId.equals(int.parse(main.id!));
    expect((await query.get(executor)).map((l) => l.name), ['alice']);
  });

  test('a relation to a table with a name of its own is loaded', () async {
    var found =
        (await (LoginQuery()..where!.id.equals(int.parse(login.id!))).getOne(
          executor,
        )).value;
    expect(found.userIdentity?.handle, 'main');
    expect(found.backupIdentity?.handle, 'backup');
  });

  test('a many-to-many through a table with a name of its own', () async {
    var found =
        (await (LoginQuery()..where!.id.equals(int.parse(login.id!))).getOne(
          executor,
        )).value;
    expect(found.grants.map((g) => g.name), ['publish']);
  });
}
