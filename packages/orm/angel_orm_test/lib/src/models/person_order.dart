library;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'person_order.g.dart';

@orm
@serializable
abstract class _PersonOrder extends Model {
  int? get personId;

  String? get name;

  double? get price;

  bool? get deleted;
}

@serializable
@Orm(tableName: 'person_orders', generateMigrations: false)
abstract class _OrderWithPersonInfo extends Model {
  String? get name;

  double? get price;

  bool? get deleted;

  @Column(expression: 'p.name')
  String? get personName;

  @Column(expression: 'p.age')
  int? get personAge;
}
