# Issue 143

Hi, i have a entity with HasMany relationship in this entity i have also a HasMany relationship and the result is without the data of the second relationship

here is a example

@Orm(tableName: 'user', generateMigrations: false)
@serializable
abstract class _User {
  @Column(type: ColumnType.int, length: 11, indexType: IndexType.primaryKey)
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get name;

  @HasMany(localKey: 'id', foreignKey: 'user_id')
  List<_UserTodo> get todos;
}

@Orm(tableName: 'user_todo', generateMigrations: false)
@serializable
abstract class_UserTodo {
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
abstract class_TodoValue {
  @Column(type: ColumnType.int, length: 11, indexType: IndexType.primaryKey)
  int get id;

  @Column(type: ColumnType.varChar, length: 255)
  String get value;

  @Column(type: ColumnType.int, length: 11)
  int get todoId;
}

the result is

User(id=1, name=test, todos=[UserTodo(id=1, userId=1, title=test, todoValues=[]),UserTodo(id=1, userId=1, title=test, todoValues=[])])

the UserTodo object was duplicated bud the TodoValue data is missing

I have one more examples

when you use two HayMany relations in the entity the result is also a bit buggy, you get the first relation *the count of the second relation and the second relation* first relation
