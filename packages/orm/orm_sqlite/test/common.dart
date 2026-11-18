import 'dart:io';

import 'package:angel3_migration_runner/sqlite.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_sqlite/angel3_orm_sqlite.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_async/sqlite_async.dart';

import 'models/car.dart';
import 'models/leg.dart';

/// A database of the tests, of one of [backends], and its executor.
class TestDatabase {
  final QueryExecutor executor;

  /// Runs a statement directly on the database, not through [executor].
  final Future<void> Function(String sql) execute;

  /// The rows of a query, by their columns' names.
  final Future<List<Map<String, Object?>>> Function(String sql) select;

  /// Whether the database is not in a transaction.
  final Future<bool> Function() autocommit;

  final Future<void> Function() close;

  TestDatabase(
    this.executor, {
    required this.execute,
    required this.select,
    required this.autocommit,
    required this.close,
  });
}

/// How the tests open a database.
class Backend {
  final String name;

  /// Whether a query outside a transaction that reads waits for it to end,
  /// as on one connection, rather than reading the rows as they were before.
  final bool readsWait;

  final Future<TestDatabase> Function(String? schema) _open;

  const Backend(this.name, this._open, {required this.readsWait});

  /// A new database, with the tables of the test models, created by their
  /// migrations, or by [schema] if given.
  Future<TestDatabase> open({String? schema}) => _open(schema);
}

/// Creates the tables of the test models on [raw], by their migrations, or
/// by [schema] if given.
Future<void> _setUp(Database raw, String? schema) async {
  if (schema != null) return raw.execute(schema);
  await SqliteMigrationRunner(
    raw,
    migrations: [LegMigration(), FootMigration(), CarMigration()],
  ).up();
}

TestDatabase _ofAsync(SqliteDatabase db) {
  var executor = SqliteAsyncExecutor(db, logger: Logger('orm_sqlite_async'));
  return TestDatabase(
    executor,
    execute: (sql) => db.execute(sql),
    select: (sql) async => [for (var row in await db.getAll(sql)) row],
    autocommit: db.getAutoCommit,
    close: executor.close,
  );
}

final List<Backend> backends = [
  Backend('sqlite3', readsWait: true, (schema) async {
    var raw = sqlite3.openInMemory();
    await _setUp(raw, schema);
    var executor = SqliteExecutor(raw, logger: Logger('orm_sqlite'));
    return TestDatabase(
      executor,
      execute: (sql) async => raw.execute(sql),
      select: (sql) async => [for (var row in raw.select(sql)) row],
      autocommit: () async => raw.autocommit,
      close: executor.close,
    );
  }),
  Backend('sqlite_async, one connection in memory', readsWait: true, (
    schema,
  ) async {
    var raw = sqlite3.openInMemory();
    await _setUp(raw, schema);
    return _ofAsync(
      SqliteDatabase.singleConnection(SqliteConnection.synchronousWrapper(raw)),
    );
  }),
  Backend('sqlite_async, a pool of a file', readsWait: false, (schema) async {
    var dir = Directory.systemTemp.createTempSync('angel3_orm_sqlite_');
    var path = '${dir.path}/test.db';
    var raw = sqlite3.open(path);
    await _setUp(raw, schema);
    raw.close();
    var db = SqliteDatabase(path: path);
    await db.initialize();
    var test = _ofAsync(db);
    return TestDatabase(
      test.executor,
      execute: test.execute,
      select: test.select,
      autocommit: test.autocommit,
      close: () async {
        await test.close();
        dir.deleteSync(recursive: true);
      },
    );
  }),
];
