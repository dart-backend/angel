import 'package:angel3_serialize/angel3_serialize.dart';
part 'has_map.g.dart';

Map? _fromString(v) => json.decode(v.toString()) as Map?;

String _toString(Map? v) => json.encode(v);

@serializable
abstract class _HasMap {
  @SerializableField(
      serializer: #_toString,
      deserializer: #_fromString,
      isNullable: false,
      serializesTo: String)
  Map? get value;
}
