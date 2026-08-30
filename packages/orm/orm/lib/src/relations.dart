import 'annotations.dart';

abstract class RelationshipType {
  static const int hasMany = 0;
  static const int hasOne = 1;
  static const int belongsTo = 2;
  static const int manyToMany = 3;
}

class Relationship {
  final int type;
  final String? localKey;
  final String? foreignKey;
  final String? foreignTable;
  final bool cascadeOnDelete;
  final JoinType? joinType;

  const Relationship(
    this.type, {
    this.localKey,
    this.foreignKey,
    this.foreignTable,
    this.cascadeOnDelete = false,
    this.joinType,
  });
}

class HasMany extends Relationship {
  const HasMany({
    super.localKey,
    super.foreignKey,
    super.foreignTable,
    bool cascadeOnDelete = false,
    super.joinType,
  }) : super(
         RelationshipType.hasMany,
         cascadeOnDelete: cascadeOnDelete == true,
       );
}

const HasMany hasMany = HasMany();

class HasOne extends Relationship {
  const HasOne({
    super.localKey,
    super.foreignKey,
    super.foreignTable,
    bool cascadeOnDelete = false,
    super.joinType,
  }) : super(RelationshipType.hasOne, cascadeOnDelete: cascadeOnDelete == true);
}

const HasOne hasOne = HasOne();

class BelongsTo extends Relationship {
  const BelongsTo({
    super.localKey,
    super.foreignKey,
    super.foreignTable,
    super.joinType,
  }) : super(RelationshipType.belongsTo);
}

const BelongsTo belongsTo = BelongsTo();

class ManyToMany extends Relationship {
  final Type through;

  const ManyToMany(
    this.through, {
    super.localKey,
    super.foreignKey,
    super.foreignTable,
    bool cascadeOnDelete = false,
    super.joinType,
  }) : super(
         RelationshipType.hasMany,
         cascadeOnDelete: cascadeOnDelete == true,
       );
}
