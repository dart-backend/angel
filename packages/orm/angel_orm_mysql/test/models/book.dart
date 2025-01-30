library;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'book.g.dart';

@serializable
@orm
class _Book extends Model {
  @BelongsTo(joinType: JoinType.inner)
  _Author? author;

  @BelongsTo(localKey: 'partner_author_id', joinType: JoinType.inner)
  _Author? partnerAuthor;

  String? name;
}

@serializable
@orm
abstract class _Author extends Model {
  @Column(length: 255, indexType: IndexType.unique)
  @SerializableField(defaultValue: 'Tobe Osakwe')
  String? get name;

  @Column(name: "pub")
  String? publisher;
}
