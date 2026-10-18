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

    test('skips a migration of a class already added', () {
      var first = UserMigration();
      var migrations = <String, Migration>{};
      addQueuedMigrations(Queue.of([first, UserMigration()]), migrations);
      expect(migrations, {'UserMigration': same(first)});
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

    test('deletes the later paths of a migration recorded twice', () {
      var legacy = LegacyPaths([
        '/old/lib/migrations.dart#UserMigration',
        '/new/lib/migrations.dart#UserMigration',
      ], migrations);
      expect(legacy.renames, {
        '/old/lib/migrations.dart#UserMigration': 'UserMigration',
      });
      expect(legacy.deletes, ['/new/lib/migrations.dart#UserMigration']);
      expect(legacy.paths, ['UserMigration']);
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

    test('renames the paths of a class name shared by two migrations', () {
      var legacy = LegacyPaths(
        ['/app/a.dart#UserMigration', '/app/b.dart#UserMigration'],
        [UserMigration(), other.UserMigration()],
      );
      expect(legacy.renames, {
        '/app/a.dart#UserMigration': 'UserMigration',
        '/app/b.dart#UserMigration': 'other_users',
      });
      expect(legacy.paths, ['UserMigration', 'other_users']);

      // Those recorded by name are not renamed again.
      legacy = LegacyPaths(
        ['UserMigration', '/app/b.dart#UserMigration'],
        [UserMigration(), other.UserMigration()],
      );
      expect(legacy.renames, {'/app/b.dart#UserMigration': 'other_users'});
    });

    test('throws for paths of a shared class name it cannot tell', () {
      expect(
        () => LegacyPaths(
          ['/app/a.dart#UserMigration'],
          [UserMigration(), other.UserMigration()],
        ),
        throwsStateError,
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
