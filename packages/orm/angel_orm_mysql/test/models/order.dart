library;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'order.g.dart';

@orm
@serializable
abstract class EntityOrder extends Model {
  @belongsTo
  EntityCustomer? get customer;

  int? get employeeId;

  DateTime? get orderDate;

  int? get shipperId;
}

@orm
@serializable
class EntityCustomer extends Model {}
