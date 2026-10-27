import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'priced.g.dart';

/// Declared precision and scale, which differ from the defaults (17, 3).
@serializable
@orm
abstract class PricedEntity extends Model {
  @Column(type: ColumnType.numeric, precision: 10, scale: 2)
  double get amount;
}
