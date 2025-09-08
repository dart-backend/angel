import 'package:angel3_serialize/angel3_serialize.dart';
part 'subclass.g.dart';

@serializable
class AnimalEntity {
  @notNull
  String? genus;
  @notNull
  String? species;
}

@serializable
class BirdEntity extends AnimalEntity {
  @DefaultsTo(false)
  bool? isSparrow;
}

var saxaulSparrow = Bird(
  genus: 'Passer',
  species: 'ammodendri',
  isSparrow: true,
);
