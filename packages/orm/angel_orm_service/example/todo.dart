import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:optional/optional.dart';
part 'todo.g.dart';

@serializable
@orm
abstract class _Todo extends Model {
  @notNull
  String? get text;

  @DefaultsTo(false)
  bool? isComplete;
}
