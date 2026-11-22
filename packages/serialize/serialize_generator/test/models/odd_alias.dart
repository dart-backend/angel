import 'package:angel3_serialize/angel3_serialize.dart';

part 'odd_alias.g.dart';

/// Keys that a Dart string literal must escape: `'`, `$` and `\`.
@Serializable(serializers: Serializers.all)
abstract class OddAliasEntity {
  @SerializableField(alias: "it's")
  String? get quote;

  @SerializableField(alias: r'$ref')
  String? get ref;

  @SerializableField(alias: r'back\slash')
  String? get backslash;

  @SerializableField(alias: r"price $ and 'tax'", isNullable: false)
  int? get price;

  @SerializableField(alias: 'two words')
  List<int>? get counts;
}
