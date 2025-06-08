library;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';
part 'person.g.dart';

@serializable
@Orm(tableName: 'persons')
class PersonEntity extends Model {
  String? name;
  int? age;
}

@serializable
@Orm(tableName: 'persons', generateMigrations: false)
class PersonWithLastOrderEntity {
  String? name;

  @Column(expression: 'po.name')
  String? lastOrderName;

  @Column(expression: 'po.price')
  double? lastOrderPrice;
}
