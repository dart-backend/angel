import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'todo.g.dart';

@serializable
@Orm(tableName: 'user_acc', generateMigrations: false)
abstract class _User {
  @Column(type: ColumnType.int, length: 11, indexType: IndexType.primaryKey)
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get name;

  @HasMany(localKey: 'id', foreignKey: 'user_acc_id')
  List<_UserTodo> get todos;
}

@Orm(tableName: 'user_todo', generateMigrations: false)
@serializable
abstract class _UserTodo {
  @Column(
    type: ColumnType.int,
    indexType: IndexType.primaryKey,
    length: 11,
    isNullable: false,
  )
  int get id;

  @Column(type: ColumnType.int, length: 11, isNullable: false, defaultValue: 0)
  int get userId;

  @Column(type: ColumnType.varChar, length: 255, isNullable: false)
  String get title;

  @HasMany(localKey: 'id', foreignKey: 'todo_id')
  List<_TodoValue> get todoValues;
}

@Orm(tableName: 'todo_value', generateMigrations: false)
@serializable
abstract class _TodoValue {
  @Column(type: ColumnType.int, length: 11, indexType: IndexType.primaryKey)
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get value;

  @Column(type: ColumnType.int, length: 11)
  int get todoId;
}
