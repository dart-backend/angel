import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/user.dart';
import 'util.dart';

void main() {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog);

  late QueryExecutor executor;
  Role? canPub, canSub;
  User? thosakwe;

  var executorFunc =
      createTables([UserMigration(), RoleMigration(), RoleUserMigration()]);

  /*
  Future<void> dumpQuery(String query) async {
    if (Platform.environment.containsKey('STFU')) return;
    print('\n');
    print('==================================================');
    print('                  DUMPING QUERY');
    print(query);
    //var rows = await executor.query(null, query, {});
    var rows = await executor.query('', query, {});
    print('\n${rows.length} row(s):');
    for (var r in rows) {
      print('  * $r');
    }
    print('==================================================\n\n');
  }
  */

  setUp(() async {
    executor = await executorFunc();

    var canPubQuery = RoleQuery()..values.name = 'can_pub';
    var canSubQuery = RoleQuery()..values.name = 'can_sub';
    canPub = (await canPubQuery.insert(executor)).value;
    print('=== CANPUB: ${canPub?.toJson()}');
    // await dumpQuery(canPubQuery.compile(Set()));
    canSub = (await canSubQuery.insert(executor)).value;
    print('=== CANSUB: ${canSub?.toJson()}');

    var thosakweQuery = UserQuery();
    thosakweQuery.values
      ..username = 'thosakwe'
      ..password = 'Hahahahayoureallythoughtiwasstupidenoughtotypethishere'
      ..email = 'thosakwe AT gmail.com';
    var result = await thosakweQuery.insert(executor);
    thosakwe = result.value;
    print('=== THOSAKWE: ${thosakwe?.toJson()}');

    // Allow thosakwe to publish...
    printSeparator('Allow thosakwe to publish');
    var thosakwePubQuery = RoleUserQuery();
    thosakwePubQuery.values
      ..userId = int.parse(thosakwe!.id!)
      ..roleId = int.parse(canPub!.id!);
    await thosakwePubQuery.insert(executor);

    // Allow thosakwe to subscribe...
    printSeparator('Allow thosakwe to subscribe');
    var thosakweSubQuery = RoleUserQuery();
    thosakweSubQuery.values
      ..userId = int.parse(thosakwe!.id!)
      ..roleId = int.parse(canSub!.id!);
    await thosakweSubQuery.insert(executor);

    // Print all users...
    // await dumpQuery('select * from users;');
    // await dumpQuery('select * from roles;');
    // await dumpQuery('select * from role_users;');
    // var query = RoleQuery()..where.id.equals(canPub.idAsInt);
    // await dumpQuery(query.compile(Set()));

    print('\n');
    print('==================================================');
    print('              GOOD STUFF BEGINS HERE              ');
    print('==================================================\n\n');
  });

  tearDown(() async => await dropTables(executor));

  Future<User?> fetchThosakwe() async {
    var query = UserQuery()..where!.id.equals(int.parse(thosakwe!.id!));
    var userOpt = await query.getOne(executor);
    expect(userOpt.isPresent, true);
    if (userOpt.isPresent) {
      return userOpt.value;
    } else {
      return null;
    }
  }

  test('fetch roles for user', () async {
    printSeparator('Fetch roles for user test');
    var user = await fetchThosakwe();

    expect(user?.roles, hasLength(2));
    expect(user?.roles, contains(canPub));
    expect(user?.roles, contains(canSub));
  });

  test('fetch users for role', () async {
    for (var role in [canPub, canSub]) {
      var query = RoleQuery()..where!.id.equals(role!.idAsInt);
      var rOpt = await query.getOne(executor);
      expect(rOpt.isPresent, true);
      rOpt.ifPresent((r) async {
        expect(r.users.toList(), [thosakwe]);
      });
    }
  });

  test('only fetches linked', () async {
    // Create a new user. The roles list should be empty,
    // be there are no related rules.
    var userQuery = UserQuery();
    userQuery.values
      ..username = 'Prince'
      ..password = 'Rogers'
      ..email = 'Nelson';
    var userOpt = await userQuery.insert(executor);
    expect(userOpt.isPresent, true);
    if (userOpt.isPresent) {
      var user = userOpt.value;
      expect(user.roles, isEmpty);

      // Fetch again, just to be doubly sure.
      var query = UserQuery()..where!.id.equals(user.idAsInt);
      var fetchedOpt = await query.getOne(executor);
      expect(fetchedOpt.isPresent, true);
      fetchedOpt.ifPresent((fetched) {
        expect(fetched.roles, isEmpty);
      });
    }
  });
}
