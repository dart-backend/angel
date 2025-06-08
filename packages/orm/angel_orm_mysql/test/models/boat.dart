import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:optional/optional.dart';

part 'boat.g.dart';

@Serializable(serializers: Serializers.all)
@orm
abstract class BoatEntity extends Model {
  @Column(defaultValue: '')
  String get make;

  @Column(defaultValue: 'none')
  String get description;

  @Column(defaultValue: false)
  bool get familyFriendly;

  //@SerializableField(defaultValue: '1970-01-01 00:00:01')
  DateTime get recalledAt;

  @Column(defaultValue: 0.0)
  double get price;

  @Column(defaultValue: 0)
  int get width;
}
