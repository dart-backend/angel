import 'schema.dart';

abstract class Migration {
  /// The name of the migration, which identifies it in the `migrations` table
  /// of the database, so it must be unique.
  ///
  /// Defaults to the name of the migration's class. Override it to keep it
  /// when the class is renamed, or in a program compiled with `--obfuscate`,
  /// where the class has no name.
  String get name => runtimeType.toString();

  void up(Schema schema);
  void down(Schema schema);
}
