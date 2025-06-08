import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'book.g.dart';

@serializable
@orm
abstract class EntityBook extends Model {
  @BelongsTo(joinType: JoinType.inner)
  EntityAuthor? get author;

  @BelongsTo(localKey: 'partner_author_id', joinType: JoinType.inner)
  EntityAuthor? partnerAuthor;

  String? get name;
}

@serializable
@orm
abstract class EntityAuthor extends Model {
  @Column(length: 255, indexType: IndexType.unique)
  @SerializableField(defaultValue: 'Tobe Osakwe')
  String? get name;

  @Column(name: "pub")
  String? get publisher;
}
