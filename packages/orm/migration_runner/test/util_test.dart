import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/src/util.dart';
import 'package:test/test.dart';

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
  });

  group('legacyPathRenames', () {
    var migrations = [UserMigration(), RenamedMigration()];

    test('maps a source path to the name of its class', () {
      expect(
        legacyPathRenames([
          r'C:\app\lib\migrations.dart#UserMigration',
          r'C:\\app\\lib\\migrations.dart#RenamedMigration',
          '/app/lib/migrations.dart#UserMigration',
        ], migrations),
        {
          r'C:\app\lib\migrations.dart#UserMigration': 'UserMigration',
          r'C:\\app\\lib\\migrations.dart#RenamedMigration': 'create_todos',
          '/app/lib/migrations.dart#UserMigration': 'UserMigration',
        },
      );
    });

    test('leaves out names and unknown classes', () {
      expect(
        legacyPathRenames([
          'UserMigration',
          '/app/lib/old.dart#GoneMigration',
        ], migrations),
        isEmpty,
      );
    });

    test('leaves out a class name shared by two migrations', () {
      expect(
        legacyPathRenames(
          ['/app/a.dart#UserMigration'],
          [UserMigration(), UserMigration()],
        ),
        isEmpty,
      );
    });
  });
}
