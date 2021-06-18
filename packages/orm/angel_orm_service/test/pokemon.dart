import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:optional/optional.dart';
part 'pokemon.g.dart';

enum PokemonType {
  fire,
  grass,
  water,
  dragon,
  poison,
  dark,
  fighting,
  electric,
  ghost
}

@serializable
@orm
abstract class _Pokemon extends Model {
  @notNull
  String? get species;

  String? get name;

  @notNull
  int? get level;

  @notNull
  PokemonType? get type1;

  PokemonType? get type2;
}
