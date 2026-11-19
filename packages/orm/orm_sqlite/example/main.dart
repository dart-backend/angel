import 'package:angel3_orm_sqlite/angel3_orm_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_async/sqlite_async.dart';

void main() async {
  // `SqliteAsyncExecutor`, as for a server: `SqliteDatabase(path: 'app.db')`
  // opens a pool of connections of a file; here, one connection in memory.
  var executor = SqliteAsyncExecutor(
    SqliteDatabase.singleConnection(
      SqliteConnection.synchronousWrapper(sqlite3.openInMemory()),
    ),
  );
  await executor.database.execute(
    'CREATE TABLE todos (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)',
  );

  await executor.transaction((tx) async {
    await tx.query('todos', 'INSERT INTO todos (title) VALUES (@title)', {
      'title': 'Write an example',
    });
  });

  var rows = await executor.query('todos', 'SELECT id, title FROM todos', {});
  print(rows); // [[1, Write an example]]

  await executor.close();

  // `SqliteExecutor`, as for tests and scripts, on `sqlite3` directly.
  var sync = SqliteExecutor(sqlite3.openInMemory());
  sync.database.execute('CREATE TABLE notes (body TEXT)');
  await sync.query('notes', 'INSERT INTO notes (body) VALUES (@b)', {'b': 'x'});
  print(await sync.query('notes', 'SELECT body FROM notes', {})); // [[x]]
  await sync.close();
}
