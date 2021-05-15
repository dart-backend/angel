import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:collection/collection.dart';
part 'goat.g.dart';

@serializable
abstract class _Goat {
  @SerializableField(defaultValue: 34)
  int get integer;

  @SerializableField(defaultValue: [34, 35])
  List<int> get list;
}
