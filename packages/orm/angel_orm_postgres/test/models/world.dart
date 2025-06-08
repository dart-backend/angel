import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:optional/optional.dart';

part 'world.g.dart';

@serializable
@Orm(tableName: 'world')
abstract class WorldEntity {
  @primaryKey
  int? id;

  @Column()
  int? randomnumber;
}
