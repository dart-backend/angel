import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/src/util.dart';
import 'package:test/test.dart';

import 'models/other_user_migration.dart' as other;

class UserMigration extends Migration {
  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}

class RenamedMigration extends Migration {
  @override
  String get name => 'create_todos';

  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}

class ClashingMigration extends RenamedMigration {}

class HashMigration extends Migration {
  @override
  String get name => 'users#v2';

  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}

class SeedMigration<T> extends Migration {
  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}

/// A migration recorded as `lib/b.dart#UserMigration` by an earlier version.
class LegacyMigration extends Migration {
  @override
  String get name => 'legacy_users';

  @override
  String get legacyPath => 'lib/b.dart#UserMigration';

  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}

void main() {
  group('Migration.name', () {
    test('defaults to the class name', () {
      expect(UserMigration().name, 'UserMigration');
    });

    test('can be overridden', () {
      expect(RenamedMigration().name, 'create_todos');
    });
  });

  group('addQueuedMigrations', () {
    test('adds migrations under their names', () {
      var migrations = <String, Migration>{};
      addQueuedMigrations(
        Queue.of([UserMigration(), RenamedMigration()]),
        migrations,
      );
      expect(migrations.keys, ['UserMigration', 'create_todos']);
    });

    test('skips a migration already added', () {
      var first = UserMigration();
      var migrations = <String, Migration>{};
      addQueuedMigrations(Queue.of([first, first]), migrations);
      expect(migrations, {'UserMigration': same(first)});
    });

    test('skips another of a class that is the same', () {
      var first = UserMigration();
      var duplicates = <Migration>[];
      var migrations = <String, Migration>{};
      addQueuedMigrations(
        Queue.of([first, UserMigration()]),
        migrations,
        isDuplicate: (a, b) => true,
        onDuplicate: duplicates.add,
      );
      expect(migrations, {'UserMigration': same(first)});
      expect(duplicates, hasLength(1));
      // Not one of another class.
      expect(
        () => addQueuedMigrations(
          Queue.of([RenamedMigration(), ClashingMigration()]),
          {},
          isDuplicate: (a, b) => true,
        ),
        throwsStateError,
      );
    });

    test('throws for two migrations of a class of the same name', () {
      // As two of a class that takes arguments, which would be one.
      expect(
        () => addQueuedMigrations(
          Queue.of([UserMigration(), UserMigration()]),
          {},
        ),
        throwsStateError,
      );
    });

    test('throws for two classes of the same name', () {
      expect(
        () => addQueuedMigrations(
          Queue.of([RenamedMigration(), ClashingMigration()]),
          {},
        ),
        throwsStateError,
      );
    });

    test(
      'takes a name with a #, which is not a path of an earlier version',
      () {
        var migrations = <String, Migration>{};
        addQueuedMigrations(Queue.of([HashMigration()]), migrations);
        expect(migrations.keys, ['users#v2']);
        expect(LegacyPaths.isLegacyPath('users#v2'), isFalse);
        expect(
          LegacyPaths.isLegacyPath('/app/lib/a.dart#UserMigration'),
          isTrue,
        );
        expect(LegacyPaths.isLegacyPath(r'C:\app\a.dart#User$1'), isTrue);
        // Recorded by name, it is neither renamed nor deleted.
        var legacy = LegacyPaths(
          ['users#v2'],
          [HashMigration(), UserMigration()],
        );
        expect(legacy.renames, isEmpty);
        expect(legacy.deletes, isEmpty);
        expect(legacy.paths, ['users#v2']);
      },
    );

    test('adds none of the queue before it throws', () {
      var queue = Queue.of(<Migration>[
        UserMigration(),
        RenamedMigration(),
        ClashingMigration(),
      ]);
      var migrations = <String, Migration>{};
      expect(() => addQueuedMigrations(queue, migrations), throwsStateError);
      expect(migrations, isEmpty);
      expect(queue, hasLength(3));
    });
  });

  test('migrationPaths reads text, and skips NULL', () {
    expect(migrationPaths(['a', null, StringBuffer('b')]), ['a', 'b']);
  });

  test('batchNumber reads an int, text and NULL', () {
    expect(batchNumber(3), 3);
    expect(batchNumber('4'), 4);
    expect(batchNumber(null), 0);
    expect(batchNumber('x'), 0);
  });

  group('LegacyPaths', () {
    var migrations = [UserMigration(), RenamedMigration()];

    test('renames a source path to the name of its class', () {
      var legacy = LegacyPaths([
        r'C:\app\lib\migrations.dart#UserMigration',
        r'C:\\app\\lib\\migrations.dart#RenamedMigration',
      ], migrations);
      expect(legacy.renames, {
        r'C:\app\lib\migrations.dart#UserMigration': 'UserMigration',
        r'C:\\app\\lib\\migrations.dart#RenamedMigration': 'create_todos',
      });
      expect(legacy.deletes, isEmpty);
      expect(legacy.paths, ['UserMigration', 'create_todos']);
    });

    test('throws for a class name of more than one path', () {
      // The project was moved, or another migration of the class name was
      // deleted, which cannot be told.
      expect(
        () => LegacyPaths([
          '/old/lib/migrations.dart#UserMigration',
          '/new/lib/migrations.dart#UserMigration',
        ], migrations),
        throwsStateError,
      );
    });

    test('deletes the later paths of a legacyPath recorded twice', () {
      var legacy = LegacyPaths(
        [r'C:\old\lib\b.dart#UserMigration', '/new/lib/b.dart#UserMigration'],
        [LegacyMigration()],
      );
      expect(legacy.renames, {
        r'C:\old\lib\b.dart#UserMigration': 'legacy_users',
      });
      expect(legacy.deletes, ['/new/lib/b.dart#UserMigration']);
      expect(legacy.paths, ['legacy_users']);
      expect(legacy.byClassName, isEmpty);
    });

    test('deletes a path whose name is already recorded', () {
      var legacy = LegacyPaths([
        '/app/lib/migrations.dart#UserMigration',
        'UserMigration',
      ], migrations);
      expect(legacy.renames, isEmpty);
      expect(legacy.deletes, ['/app/lib/migrations.dart#UserMigration']);
      expect(legacy.paths, ['UserMigration']);
    });

    test('leaves names and unknown classes as they are', () {
      var paths = ['UserMigration', '/app/lib/old.dart#GoneMigration'];
      var legacy = LegacyPaths(paths, migrations);
      expect(legacy.renames, isEmpty);
      expect(legacy.deletes, isEmpty);
      expect(legacy.paths, paths);
    });

    test('throws for a class name shared by two migrations', () {
      // Which of them was run as each path cannot be told.
      for (var paths in [
        ['/app/a.dart#UserMigration'],
        ['/app/a.dart#UserMigration', '/app/b.dart#UserMigration'],
      ]) {
        expect(
          () => LegacyPaths(paths, [UserMigration(), other.UserMigration()]),
          throwsStateError,
        );
      }
    });

    test('tells a class name shared by two migrations by a legacyPath', () {
      var legacy = LegacyPaths(
        ['/app/lib/a.dart#UserMigration', '/app/lib/b.dart#UserMigration'],
        [UserMigration(), LegacyMigration()],
      );
      expect(legacy.renames, {
        '/app/lib/a.dart#UserMigration': 'UserMigration',
        '/app/lib/b.dart#UserMigration': 'legacy_users',
      });
      // Only the one told by its class name, which is logged.
      expect(legacy.byClassName, {'/app/lib/a.dart#UserMigration'});
    });

    test('matches the class name of a generic migration', () {
      // Recorded by its class name, without its type arguments.
      var legacy = LegacyPaths(
        ['/app/lib/seed.dart#SeedMigration'],
        [SeedMigration<int>()],
      );
      expect(legacy.renames, {
        '/app/lib/seed.dart#SeedMigration': 'SeedMigration<int>',
      });
    });

    test('matches a legacyPath at the start of a part of the path', () {
      expect(
        LegacyPaths(
          ['/app/lib/ab.dart#UserMigration'],
          [LegacyMigration()],
        ).renames,
        isEmpty,
      );
    });

    test('renames a path given twice once', () {
      var path = '/app/a.dart#UserMigration';
      var legacy = LegacyPaths([path, path], migrations);
      expect(legacy.renames, {path: 'UserMigration'});
      expect(legacy.deletes, isEmpty);
    });
  });
}
