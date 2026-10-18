import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';

/// Moves the migrations of [queue] into [migrations], under their
/// [Migration.name].
///
/// A migration of a class already added is skipped. Throws a [StateError] if
/// two migrations of different classes have the same name.
void addQueuedMigrations(
  Queue<Migration> queue,
  Map<String, Migration> migrations,
) {
  while (queue.isNotEmpty) {
    var migration = queue.removeFirst();
    var name = migration.name;
    var added = migrations[name];
    if (added == null) {
      migrations[name] = migration;
    } else if (added.runtimeType != migration.runtimeType) {
      throw StateError(
        'Migrations ${added.runtimeType} and ${migration.runtimeType} have '
        'the same name "$name"; override `name` in one of them.',
      );
    }
  }
}

/// The changes to the paths of the `migrations` table written by a version
/// before 10.0.0, `<source file>#<class name>`, which are replaced by the
/// [Migration.name] of the migration of that class.
class LegacyPaths {
  /// The paths to rename, mapped to their new names.
  final Map<String, String> renames;

  /// The paths to delete, as the table already has their new name, as when
  /// the project was moved and the migration was recorded at both paths.
  final List<String> deletes;

  /// The paths of the table once changed, in the order they were given.
  final List<String> paths;

  LegacyPaths._(this.renames, this.deletes, this.paths);

  /// The changes to [paths], the paths of the table, oldest first, so that
  /// the oldest of the paths of a migration is the one renamed.
  ///
  /// A path whose class is not that of exactly one of [migrations] is left as
  /// it is.
  factory LegacyPaths(List<String> paths, Iterable<Migration> migrations) {
    var renames = <String, String>{};
    var deletes = <String>[];
    var changed = <String>[];
    var names = paths.where((p) => !p.contains('#')).toSet();
    for (var path in paths) {
      var name = _legacyName(path, migrations);
      if (name == null) {
        changed.add(path);
      } else if (names.add(name)) {
        renames[path] = name;
        changed.add(name);
      } else {
        deletes.add(path);
      }
    }
    return LegacyPaths._(renames, deletes, changed);
  }

  static String? _legacyName(String path, Iterable<Migration> migrations) {
    var hash = path.lastIndexOf('#');
    if (hash < 0) return null;
    var className = path.substring(hash + 1);
    var matches = migrations
        .where((m) => m.runtimeType.toString() == className)
        .toList();
    return matches.length == 1 ? matches.single.name : null;
  }
}
