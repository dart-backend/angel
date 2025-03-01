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
      TodoNoteMigration()
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

      /*
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
      */

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
    });

    test('can fetch children', () async {
      var query = UserQuery()..where!.id.equals(userId);
      var userOpt = await (query.getOne(executor));
      expect(userOpt.isPresent, true);
      userOpt.ifPresent((user) {
        logger.fine(user);
        expect(user.todos, hasLength(3));
      });
    });
  });
}
