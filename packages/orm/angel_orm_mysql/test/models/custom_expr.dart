import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'custom_expr.g.dart';

@serializable
@orm
class _Numbers extends Model {
  @Column(expression: 'SELECT 2')
  int? two;
}

@serializable
@orm
class _Alphabet extends Model {
  String? value;

  @belongsTo
  _Numbers? numbers;
}
