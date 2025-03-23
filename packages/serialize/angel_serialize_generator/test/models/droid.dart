import 'package:angel3_serialize/angel3_serialize.dart';

import 'character.dart';

part 'droid.g.dart';

@serializable
abstract class _Droid extends Model implements Character {
  String get position;

  num get age;
}
