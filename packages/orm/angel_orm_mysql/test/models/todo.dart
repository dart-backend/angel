import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'todo.g.dart';

@serializable
@Orm(tableName: 'user_acc', generateMigrations: true)
abstract class UserEntity {
  @Column(type: ColumnType.serial, indexType: IndexType.primaryKey)
  @PrimaryKey()
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get name;

  // Not supported
  @HasMany(localKey: 'id', foreignKey: 'user_id')
  List<UserTodoEntity> get todos;

  @HasMany(localKey: 'id', foreignKey: 'user_id')
  List<UserAddressEntity> get address;
}

@Orm(tableName: 'user_addr', generateMigrations: true)
@serializable
abstract class UserAddressEntity {
  @Column(
      type: ColumnType.serial,
      indexType: IndexType.primaryKey,
      isNullable: false)
  int get id;

  @Column(type: ColumnType.int, isNullable: false)
  int get userId;

  @Column(type: ColumnType.varChar, length: 255, isNullable: false)
  String get address;
}

@Orm(tableName: 'user_todo', generateMigrations: true)
@serializable
abstract class UserTodoEntity {
  @Column(
      type: ColumnType.serial,
      indexType: IndexType.primaryKey,
      isNullable: false)
  int get id;

  @Column(type: ColumnType.int, isNullable: false)
  int get userId;

  @Column(type: ColumnType.varChar, length: 255, isNullable: false)
  String get title;

  @HasMany(localKey: 'id', foreignKey: 'todo_value_id')
  List<TodoValueEntity> get todoValues;

  @HasMany(localKey: 'id', foreignKey: 'todo_note_id')
  List<TodoNoteEntity> get todoNotes;
}

@Orm(tableName: 'todo_value', generateMigrations: true)
@serializable
abstract class TodoValueEntity {
  @Column(type: ColumnType.serial, indexType: IndexType.primaryKey)
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get value;

  @Column(type: ColumnType.int)
  int get todoId;

  String? get description;
}

@Orm(tableName: 'todo_note', generateMigrations: true)
@serializable
abstract class TodoNoteEntity {
  @Column(type: ColumnType.serial, indexType: IndexType.primaryKey)
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get note;

  @Column(type: ColumnType.int)
  int get todoId;

  String? get description;
}
