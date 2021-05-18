import 'dart:async';
import 'package:angel3_migration/angel3_migration.dart';

abstract class MigrationRunner {
  void addMigration(Migration migration);

  Future up();

  Future rollback();

  Future reset();

  Future close();
}
