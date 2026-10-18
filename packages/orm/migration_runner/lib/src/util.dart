import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';

/// Moves the migrations of [queue] into [migrations], under their
/// [Migration.name].
///
/// A migration already added, or another of its class that [isDuplicate]
/// says is the same, such as one that makes the same changes, is skipped, and
/// given to [onDuplicate]. Throws a [StateError] if two other migrations have
/// the same name, as do two of a class that takes arguments, such as
/// `TableMigration('users')` and `TableMigration('posts')`, which would be
/// recorded as one, before any of [queue] is moved, so that none of them is
/// lost.
void addQueuedMigrations(
  Queue<Migration> queue,
  Map<String, Migration> migrations, {
  bool Function(Migration added, Migration other) isDuplicate = identical,
  void Function(Migration duplicate)? onDuplicate,
}) {
  var added = {...migrations};
  for (var migration in queue) {
    var name = migration.name;
    var other = added[name];
    if (other == null) {
      added[name] = migration;
    } else if (identical(other, migration) ||
        (other.runtimeType == migration.runtimeType &&
            isDuplicate(other, migration))) {
      if (!identical(other, migration)) onDuplicate?.call(migration);
    } else {
      var classes = other.runtimeType == migration.runtimeType
          ? 'Two migrations of ${migration.runtimeType}'
          : 'Migrations ${other.runtimeType} and ${migration.runtimeType}';
      throw StateError(
        '$classes have the same name "$name"; override `name` so that each '
        'has its own.',
      );
    }
  }
  queue.clear();
  migrations.addAll(added);
}

/// The paths of [rows], the values of a query of the paths of the
/// `migrations` table, as text, which a client may give as a `Blob`. A `NULL`
/// path is skipped.
List<String> migrationPaths(Iterable<Object?> rows) => [
  for (var value in rows)
    if (value != null) value.toString(),
];

/// The batch number of [value], the `MAX(batch)` of the `migrations` table,
/// which a client may give as an [int] or as text, and `NULL` for an empty
/// table, which is 0.
int batchNumber(Object? value) =>
    value is int ? value : int.tryParse('${value ?? 0}') ?? 0;

/// Renames and deletes the paths of the `migrations` table written by a
/// version before 10.0.0, as [LegacyPaths] of [paths] and [migrations], with
/// [rename] and [delete], and returns the paths of the table once changed.
Future<List<String>> applyLegacyPaths(
  List<String> paths,
  Iterable<Migration> migrations, {
  required Future<void> Function(String path, String name) rename,
  required Future<void> Function(String path) delete,
  required Logger log,
}) async {
  var legacy = LegacyPaths(paths, migrations);
  for (var MapEntry(key: path, value: name) in legacy.renames.entries) {
    await rename(path, name);
    if (legacy.byClassName.contains(path)) {
      log.warning(
        'Renamed "$path" to "$name" in "migrations" table, as the only '
        'migration of its class name; give it a legacyPath if it is not.',
      );
    } else {
      log.info('Renamed "$path" to "$name" in "migrations" table.');
    }
  }
  for (var path in legacy.deletes) {
    await delete(path);
    log.info('Removed "$path", recorded again, from "migrations" table.');
  }
  return legacy.paths;
}

/// The changes to the paths of the `migrations` table written by a version
/// before 10.0.0, `<source file>#<class name>`, which are replaced by the
/// [Migration.name] of their migration.
///
/// As the runner cannot tell the source file of a migration, the migration
/// of a path is the one whose [Migration.legacyPath] it ends with, or else
/// the only migration of its class name, if no other path has that class
/// name. A path that may be of more than one migration, or that is one of
/// more than one of a class name, throws a [StateError], rather than a
/// migration being run again, or not run at all.
class LegacyPaths {
  /// The paths to rename, mapped to their new names.
  final Map<String, String> renames;

  /// The paths of [renames] whose migration is told only by its class name.
  final Set<String> byClassName;

  /// The paths to delete, as the table already has their new name, as when
  /// the project was moved and the migration was recorded at both paths.
  final List<String> deletes;

  /// The paths of the table once changed, in the order they were given.
  final List<String> paths;

  LegacyPaths._(this.renames, this.byClassName, this.deletes, this.paths);

  /// The changes to [paths], the paths of the table, oldest first, so that
  /// the oldest of the paths of a migration is the one renamed. A path whose
  /// class is not that of one of [migrations] is left as it is.
  factory LegacyPaths(List<String> paths, Iterable<Migration> migrations) {
    var names = paths.where((p) => !p.contains('#')).toSet();
    // Each once, as an update or delete of a path is of all its rows.
    var legacy = {
      for (var path in paths)
        if (path.contains('#')) path,
    };

    var migrationOf = <String, Migration>{};
    var byClassName = <String>{};
    var unknown = <String>[];

    // By the legacy paths given.
    for (var path in legacy) {
      var matches = [
        for (var m in migrations)
          if (m.legacyPath case var legacyPath?)
            if (_endsWithPath(path, legacyPath)) m,
      ];
      if (matches.length > 1) {
        unknown.add(path);
      } else if (matches.length == 1) {
        migrationOf[path] = matches.single;
      }
    }

    // By the class name, of a path of no other.
    var byClass = <String, List<String>>{};
    for (var path in legacy) {
      if (!migrationOf.containsKey(path) && !unknown.contains(path)) {
        (byClass[_className(path)] ??= []).add(path);
      }
    }
    byClass.forEach((className, classPaths) {
      var candidates = [
        for (var m in migrations)
          if (m.legacyPath == null && _classNameOf(m) == className) m,
      ];
      if (candidates.isEmpty) return;
      if (candidates.length == 1 && classPaths.length == 1) {
        migrationOf[classPaths.single] = candidates.single;
        byClassName.add(classPaths.single);
      } else {
        unknown.addAll(classPaths);
      }
    });

    if (unknown.isNotEmpty) {
      throw StateError(
        'Cannot tell the migrations of the paths ${unknown.join(', ')} of the '
        '"migrations" table, recorded by a version before 10.0.0, as their '
        'class names are those of more than one path or migration. Give each '
        'of those migrations a legacyPath, the end of its path, such as '
        '"lib/migrations/users.dart#UserMigration", or set each path to the '
        'name of its migration: UPDATE migrations SET path = \'<name>\' '
        'WHERE path = \'<path>\'.',
      );
    }

    var renames = <String, String>{};
    var deletes = <String>[];
    var changed = <String>[];
    for (var path in paths) {
      var migration = migrationOf[path];
      if (migration == null) {
        changed.add(path);
      } else if (renames.containsKey(path)) {
        // A path given twice, renamed once.
        changed.add(renames[path]!);
      } else if (names.add(migration.name)) {
        renames[path] = migration.name;
        changed.add(migration.name);
      } else if (!deletes.contains(path)) {
        deletes.add(path);
      }
    }
    byClassName.retainAll(renames.keys);
    return LegacyPaths._(renames, byClassName, deletes, changed);
  }

  static String _className(String path) =>
      path.substring(path.lastIndexOf('#') + 1);

  /// The name of the class of [migration], without its type arguments, as
  /// the mirrors of an earlier version gave it: `SeedMigration`, not
  /// `SeedMigration<User>`.
  static String _classNameOf(Migration migration) =>
      migration.runtimeType.toString().replaceFirst(RegExp(r'<.*$'), '');

  /// Whether [path] ends with [legacyPath], at the start of a part of it, and
  /// with either separator of Windows or other systems, which a path may
  /// also have doubled, as an earlier version escaped it for MySQL.
  static bool _endsWithPath(String path, String legacyPath) {
    String normalize(String p) =>
        p.replaceAll(r'\\', '/').replaceAll(r'\', '/').toLowerCase();
    var p = normalize(path);
    var end = normalize(legacyPath);
    return p == end || p.endsWith(end.startsWith('/') ? end : '/$end');
  }
}
