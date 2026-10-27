import 'package:angel3_migration/angel3_migration.dart';

/// A migration of the class name `UserMigration` whose legacyPath has a typo
/// (`migration` for `migrations`).
class UserMigration extends Migration {
  @override
  String get legacyPath => 'lib/migration/b.dart#UserMigration';

  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}
