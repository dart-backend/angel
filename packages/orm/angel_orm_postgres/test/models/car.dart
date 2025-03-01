import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';
part 'car.g.dart';

@serializable
@orm
class _Car extends Model {
  String? make;
  String? description;
  bool? familyFriendly;
  DateTime? recalledAt;
  double? price;
}
