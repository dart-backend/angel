import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// A runner of a `migrations` table in memory, which records the `up` and
/// `down` it runs in [log].
class MemoryRunner extends SqlMigrationRunner {
  /// The rows of the table, as `(id, batch, path)`.
  final List<(int, int, String?)> rows = [];

  final List<String> runs = [];

  MemoryRunner(Iterable<Migration> migrations)
    : super(Logger('MemoryRunner'), migrations);

  @override
  Future<void> createMigrationsTable() async {}

  /// Only the queries of the runner.
  @override
  Future<List<Object?>> queryColumn(String sql) async {
    if (sql.startsWith('SELECT MAX(batch)')) {
      return [
        rows.isEmpty
            ? null
            : rows.map((r) => r.$2).reduce((a, b) => a > b ? a : b),
      ];
    }
    var sorted = [...rows];
    if (sql.contains('ORDER BY id DESC')) {
      sorted.sort((a, b) => b.$1.compareTo(a.$1));
    } else if (sql.contains('ORDER BY batch DESC, id DESC')) {
      sorted.sort(
        (a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : b.$1.compareTo(a.$1),
      );
    }
    var batch = RegExp(r'batch = (\d+)').firstMatch(sql)?[1];
    return [
      for (var r in sorted)
        if (batch == null || r.$2 == int.parse(batch)) r.$3,
    ];
  }

  @override
  Future<void> renamePath(String path, String name) async {
    for (var (i, r) in rows.indexed.toList()) {
      if (r.$3 == path) rows[i] = (r.$1, r.$2, name);
    }
  }

  @override
  Future<void> deletePath(String path) async =>
      rows.removeWhere((r) => r.$3 == path);

  @override
  Future<void> runUp(String name, Migration migration, int batch) async {
    migration.up(_NoSchema());
    runs.add('up $name');
    rows.add((rows.length + 1, batch, name));
  }

  @override
  Future<void> runDown(String name, Migration migration) async {
    runs.add('down $name');
    await deletePath(name);
  }

  @override
  String compileUp(Migration migration) => migration.name;

  @override
  Future close() async {}
}

class _NoSchema implements Schema {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class NamedMigration extends Migration {
  @override
  final String name;

  final bool fails;

  NamedMigration(this.name, {this.fails = false});

  @override
  void up(Schema schema) {
    if (fails) throw StateError('fails');
  }

  @override
  void down(Schema schema) {}
}

void main() {
  test('runs the migrations not recorded, in a new batch', () async {
    var a = NamedMigration('a'), b = NamedMigration('b');
    var runner = MemoryRunner([a]);
    await runner.up();
    runner.addMigration(b);
    await runner.up();
    expect(runner.runs, ['up a', 'up b']);
    expect(runner.rows, [(1, 1, 'a'), (2, 2, 'b')]);
  });

  test('stops at a migration that fails, and throws', () async {
    var runner = MemoryRunner([
      NamedMigration('a'),
      NamedMigration('b', fails: true),
      NamedMigration('c'),
    ]);
    await expectLater(runner.up(), throwsStateError);
    expect(runner.runs, ['up a']);
  });

  test('rolls back the last batch newest first', () async {
    var runner = MemoryRunner([NamedMigration('b'), NamedMigration('a')])
      ..rows.addAll([(1, 1, 'a'), (2, 1, 'b')]);
    await runner.rollback();
    expect(runner.runs, ['down b', 'down a']);
    expect(runner.rows, isEmpty);
  });

  test('undoes a migration recorded twice once', () async {
    var runner = MemoryRunner([NamedMigration('a'), NamedMigration('b')])
      ..rows.addAll([(1, 1, 'a'), (2, 1, 'b'), (3, 2, 'a'), (4, 2, null)]);
    await runner.reset();
    expect(runner.runs, ['down a', 'down b']);
  });
}
