import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';

class UserMigration implements Migration {
  @override
  void up(Schema schema) {
    schema.create('users', (table) {
      table
        ..integer('id').primaryKey()
        ..varChar('username', length: 32).unique()
        ..varChar('password')
        ..boolean('account_confirmed').defaultsTo(false);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('users');
  }
}

class TodoMigration implements Migration {
  @override
  void up(Schema schema) {
    schema.create('todos', (table) {
      table
        ..integer('id').primaryKey()
        ..integer('user_id').references('users', 'id').onDeleteCascade()
        ..varChar('text')
        ..boolean('completed').defaultsTo(false);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('todos');
  }
}

class ItemMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('items', (table) {
      table
        ..integer('id').primaryKey()
        ..varChar('name', length: 64)
        ..timeStamp('created_at').defaultsTo(currentTimestamp);
    });
  }

  @override
  void down(Schema schema) => schema.drop('items');
}

class CarMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'cars',
      (table) {
        table.integer('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.varChar(
          'make',
          length: 255,
        );
        table.varChar(
          'description',
          length: 255,
        );
        table.boolean('family_friendly');
        table.timeStamp('recalled_at');
        table.double('price');
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('cars');
  }
}
