import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/todo.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });

  var logger = Logger('has_many2_test');

  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;
  late User user;
  late int userId;

  setUp(() async {
    var userQuery = UserQuery();

    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      UserMigration(),
      UserTodoMigration(),
      UserAddressMigration(),
      TodoValueMigration(),
      TodoNoteMigration(),
    ]);

    userQuery.values.name = 'Tim';
    user = (await userQuery.insert(executor)).value;
    userId = user.id;
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) {
      await conn.close();
    }
  });

  group('has many children', () {
    setUp(() async {
      // Add User todo
      var userTodoQuery = UserTodoQuery();
      userTodoQuery.values
        ..userId = userId
        ..title = 'Office';
      var userTodo = (await userTodoQuery.insert(executor)).value;
      print(userTodo);

      var todoValueQuery = TodoValueQuery();
      todoValueQuery.values
        ..todoId = userTodo.id
        ..value = 'Purchase Laptop';
      await todoValueQuery.insert(executor);

      todoValueQuery = TodoValueQuery();
      todoValueQuery.values
        ..todoId = userTodo.id
        ..value = 'Purchase Monitor';
      await todoValueQuery.insert(executor);

      todoValueQuery = TodoValueQuery();
      todoValueQuery.values
        ..todoId = userTodo.id
        ..value = 'Purchase Paper';
      await todoValueQuery.insert(executor);

      userTodoQuery = UserTodoQuery();
      userTodoQuery.values
        ..userId = userId
        ..title = 'Home';
      userTodo = (await userTodoQuery.insert(executor)).value;

      userTodoQuery = UserTodoQuery();
      userTodoQuery.values
        ..userId = userId
        ..title = 'Online';
      userTodo = (await userTodoQuery.insert(executor)).value;

      // Add User Address
      var userAddressQuery = UserAddressQuery();
      userAddressQuery.values
        ..userId = userId
        ..address = 'Office Address';
      var userAddress = (await userAddressQuery.insert(executor)).value;
      print(userAddress);
    });

    test('can fetch children', () async {
      var query = UserQuery()..where!.id.equals(userId);
      var userOpt = await (query.getOne(executor));
      expect(userOpt.isPresent, true);
      userOpt.ifPresent((user) {
        logger.fine(user);
        expect(user.todos, hasLength(3));
        var office = user.todos.firstWhere((t) => t.title == 'Office');
        // In the order of the rows, which the query does not set.
        expect(
          office.todoValues.map((v) => v.value),
          unorderedEquals([
            'Purchase Laptop',
            'Purchase Monitor',
            'Purchase Paper',
          ]),
        );
        expect(user.address.map((a) => a.address), ['Office Address']);
      });
    });

    test(
      'loads children with the conditions and order of their query',
      () async {
        var query = UserQuery()..where!.id.equals(userId);
        query.todos
          ..where!.title.notEquals('Online')
          ..orderBy('title');
        var user = (await query.getOne(executor)).value;
        expect(user.todos.map((t) => t.title), ['Home', 'Office']);

        // Again, with the same query: its conditions are not added twice.
        user = (await query.getOne(executor)).value;
        expect(user.todos.map((t) => t.title), ['Home', 'Office']);
      },
    );

    group('a limit counts records, not the rows of their joins', () {
      setUp(() async {
        var other = UserQuery();
        other.values.name = 'Ann';
        await other.insert(executor);
      });

      test('with limit', () async {
        var users =
            await (UserQuery()
                  ..orderBy('id')
                  ..limit(1))
                .get(executor);
        expect(users.map((u) => u.name), ['Tim']);
        expect(users.first.todos, hasLength(3));
        var office = users.first.todos.firstWhere((t) => t.title == 'Office');
        expect(office.todoValues, hasLength(3));
      });

      test('with offset', () async {
        var users =
            await (UserQuery()
                  ..orderBy('id')
                  ..limit(1)
                  ..offset(1))
                .get(executor);
        expect(users.map((u) => u.name), ['Ann']);
        expect(users.first.todos, isEmpty);
      });

      test('with getOne', () async {
        var user = await (UserQuery()..where!.id.equals(userId)).getOne(
          executor,
        );
        expect(user.value.todos, hasLength(3));
      });
    });
  });
}
