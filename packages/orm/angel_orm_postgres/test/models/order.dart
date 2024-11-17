library;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'order.g.dart';

@orm
@serializable
abstract class _Order extends Model {
  @belongsTo
  _Customer? get customer;

  int? get employeeId;

  DateTime? get orderDate;

  int? get shipperId;
}

@orm
@serializable
class _Customer extends Model {}
