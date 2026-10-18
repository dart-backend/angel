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

/// The paths of the `migrations` table written by a version before 10.0.0,
/// `<source file>#<class name>`, mapped to the [Migration.name] of the
/// migration of that class, which replaces them.
///
/// A path whose class is not that of exactly one of [migrations] is left out.
Map<String, String> legacyPathRenames(
  Iterable<String> paths,
  Iterable<Migration> migrations,
) {
  var renames = <String, String>{};
  for (var path in paths) {
    var hash = path.lastIndexOf('#');
    if (hash < 0) continue;
    var className = path.substring(hash + 1);
    var matches = migrations
        .where((m) => m.runtimeType.toString() == className)
        .toList();
    if (matches.length == 1) renames[path] = matches.single.name;
  }
  return renames;
}
