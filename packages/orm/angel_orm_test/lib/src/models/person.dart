library angel_orm3.generator.models.person;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';
part 'person.g.dart';

@serializable
@Orm(tableName: 'persons')
class _Person extends Model {
  String? name;
  int? age;
}

@serializable
@Orm(tableName: 'persons', generateMigrations: false)
class _PersonWithLastOrder {
  String? name;

  @Column(expression: 'po.name')
  String? lastOrderName;

  @Column(expression: 'po.price')
  double? lastOrderPrice;
}
