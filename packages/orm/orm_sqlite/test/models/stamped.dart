import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'stamped.g.dart';

/// A model of defaults of the database: of SQL, as `currentTimestamp`, and
/// of a value.
@serializable
@orm
abstract class StampedEntity extends Model {
  String? get name;

  @Column(defaultValue: currentTimestamp)
  DateTime? get seenAt;

  @Column(defaultValue: RawSql("'n/a'"))
  String? get code;

  @Column(defaultValue: 'plain')
  String? get label;
}
