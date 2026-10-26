import 'package:angel3_migration/angel3_migration.dart';

/// A migration of the same class name as another, in another library, so
/// with a name of its own.
class UserMigration extends Migration {
  @override
  String get name => 'other_users';

  @override
  void up(Schema schema) {}

  @override
  void down(Schema schema) {}
}
