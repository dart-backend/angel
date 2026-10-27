import 'schema.dart';

abstract class Migration {
  /// The name of the migration, which identifies it in the `migrations` table
  /// of the database, so it must be unique.
  ///
  /// Defaults to the name of the migration's class. Override it to keep it
  /// when the class is renamed, or in a program compiled with `--obfuscate`,
  /// where the class has no name.
  String get name => runtimeType.toString();

  /// The end of the path by which a version of the migration runner before
  /// 10.0.0 recorded the migration, `<source file>#<class name>`, such as
  /// `lib/migrations/users.dart#UserMigration`, or `null` if not given.
  ///
  /// The runner renames the rows of the `migrations` table whose path ends
  /// with it to [name]. Without it, a row is renamed only if its class name
  /// is that of no other row and of no other migration, as which of them was
  /// run cannot be told otherwise.
  String? get legacyPath => null;

  void up(Schema schema);
  void down(Schema schema);
}
