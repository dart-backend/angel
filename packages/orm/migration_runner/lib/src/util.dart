import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';

/// Moves the migrations of [queue] into [migrations], under their
/// [Migration.name].
///
/// A migration of a class already added is skipped. Throws a [StateError] if
/// two migrations of different classes have the same name, before any of
/// [queue] is moved, so that none of them is lost.
void addQueuedMigrations(
  Queue<Migration> queue,
  Map<String, Migration> migrations,
) {
  var added = {...migrations};
  for (var migration in queue) {
    var name = migration.name;
    var other = added[name];
    if (other == null) {
      added[name] = migration;
    } else if (other.runtimeType != migration.runtimeType) {
      throw StateError(
        'Migrations ${other.runtimeType} and ${migration.runtimeType} have '
        'the same name "$name"; override `name` in one of them.',
      );
    }
  }
  queue.clear();
  migrations.addAll(added);
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
  /// The paths of a class of more than one of [migrations], in different
  /// files, are those of its migrations not recorded by name, in the order of
  /// [migrations], if there are as many of them; as a path has no migration
  /// without its source file, a [StateError] is thrown otherwise, rather than
  /// running a migration again. A path whose class is not that of one of
  /// [migrations] is left as it is.
  factory LegacyPaths(List<String> paths, Iterable<Migration> migrations) {
    var names = paths.where((p) => !p.contains('#')).toSet();

    // The paths of each class, oldest first, each once, as an update or
    // delete of a path is of all its rows.
    var byClass = <String, Set<String>>{};
    for (var path in paths) {
      var className = _className(path);
      if (className != null) (byClass[className] ??= {}).add(path);
    }

    // The new name of each path, or `null` to delete it.
    var changes = <String, String?>{};
    for (var MapEntry(key: className, value: classPaths) in byClass.entries) {
      var classMigrations = migrations
          .where((m) => m.runtimeType.toString() == className)
          .toList();
      if (classMigrations.isEmpty) continue;
      if (classMigrations.length == 1) {
        var name = classMigrations.single.name;
        for (var path in classPaths) {
          changes[path] = names.add(name) ? name : null;
        }
        continue;
      }
      var unrecorded = [
        for (var m in classMigrations)
          if (!names.contains(m.name)) m.name,
      ];
      if (unrecorded.isEmpty) {
        for (var path in classPaths) {
          changes[path] = null;
        }
      } else if (unrecorded.length == classPaths.length) {
        for (var (i, path) in classPaths.indexed) {
          changes[path] = unrecorded[i];
          names.add(unrecorded[i]);
        }
      } else {
        throw StateError(
          'Cannot tell which of the migrations ${unrecorded.join(', ')} of '
          'class $className were run as ${classPaths.join(', ')} in the '
          '"migrations" table; set the path of each of them that was run to '
          'its name.',
        );
      }
    }

    var renames = <String, String>{};
    var deletes = <String>[];
    var changed = <String>[];
    for (var path in paths) {
      if (!changes.containsKey(path)) {
        changed.add(path);
      } else if (changes[path] case var name?) {
        renames[path] = name;
        changed.add(name);
      } else {
        deletes.add(path);
      }
    }
    return LegacyPaths._(renames, deletes, changed);
  }

  static String? _className(String path) {
    var hash = path.lastIndexOf('#');
    return hash < 0 ? null : path.substring(hash + 1);
  }
}
