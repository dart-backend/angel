import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'leg.g.dart';

@serializable
@orm
class LegEntity extends Model {
  @hasOne
  FootEntity? foot;

  String? name;
}

@serializable
@Orm(tableName: 'feet')
class FootEntity extends Model {
  int? legId;

  double? nToes;
}
