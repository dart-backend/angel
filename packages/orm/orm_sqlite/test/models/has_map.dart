import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'has_map.g.dart';

@orm
@serializable
abstract class HasMapEntity {
  Map? get value;

  List? get list;
}
