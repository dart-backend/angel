library angel3_orm_generator.test.models.leg;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_model/angel3_model.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'leg.g.dart';

@serializable
@orm
class _Leg extends Model {
  @hasOne
  _Foot? foot;

  String? name;
}

@serializable
@Orm(tableName: 'feet')
class _Foot extends Model {
  int? legId;

  double? nToes;
}
