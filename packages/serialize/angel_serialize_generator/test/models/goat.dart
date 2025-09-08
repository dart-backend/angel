import 'package:angel3_serialize/angel3_serialize.dart';
part 'goat.g.dart';

@serializable
abstract class GoatEntity {
  @SerializableField(defaultValue: 34)
  int get integer;

  @SerializableField(defaultValue: [34, 35])
  List<int> get list;
}
