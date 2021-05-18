import 'dart:convert';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:collection/collection.dart';
import 'package:optional/optional.dart';

part 'has_map.g.dart';

// String _boolToCustom(bool v) => v ? 'yes' : 'no';
// bool _customToBool(v) => v == 'yes';

@orm
@serializable
abstract class _HasMap {
  Map? get value;

  List? get list;

  // TODO: Support custom serializers
  // @SerializableField(
  //     serializer: #_boolToCustom,
  //     deserializer: #_customToBool,
  //     serializesTo: String)
  // bool get customBool;
}
