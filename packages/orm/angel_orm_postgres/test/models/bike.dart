import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:optional/optional.dart';

part 'bike.g.dart';

@serializable
@orm
abstract class _Bike extends Model {
  String get make;

  String get description;

  bool get familyFriendly;

  DateTime get recalledAt;

  double get price;

  int get width;
}
