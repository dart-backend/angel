import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:optional/optional.dart';

part 'boat.g.dart';

@serializable
@orm
abstract class _Boat extends Model {
  @SerializableField(defaultValue: '')
  String get make;

  @SerializableField(defaultValue: 'none')
  String get description;

  @SerializableField(defaultValue: false)
  bool get familyFriendly;

  //@SerializableField(defaultValue: '1970-01-01 00:00:00')
  DateTime get recalledAt;

  @SerializableField(defaultValue: 0.0)
  double get price;

  @SerializableField(defaultValue: 0)
  int get width;
}
