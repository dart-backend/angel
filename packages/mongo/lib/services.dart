library;

import 'dart:async';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_merge_map/belatuk_merge_map.dart';
import 'package:mongo_dart/mongo_dart.dart';

part 'mongo_service.dart';

Map<String, dynamic> _transformId(Map<String, dynamic> doc) {
  var result = Map<String, dynamic>.from(doc);
  result
    ..['id'] = doc['_id']
    ..remove('_id');

  return result;
}

ObjectId _makeId(id) {
  try {
    return (id is ObjectId) ? id : ObjectId.fromHexString(id.toString());
  } catch (e) {
    throw AngelHttpException.badRequest();
  }
}

const List<String> _sensitiveFieldNames = [
  'id',
  '_id',
  'createdAt',
  'updatedAt'
];

Map<String, dynamic> _removeSensitive(Map<String, dynamic> data) {
  return data.keys
      .where((k) => !_sensitiveFieldNames.contains(k))
      .fold({}, (map, key) => map..[key] = data[key]);
}

const List<String> _noQuery = ['__requestctx', '__responsectx'];

Map<String, dynamic> _filterNoQuery(Map<String, dynamic> data) {
  return data.keys.fold({}, (map, key) {
    var value = data[key];

    if (_noQuery.contains(key) ||
        value is RequestContext ||
        value is ResponseContext) {
      return map;
    }
    if (key is! Map) return map..[key] = value;
    return map..[key] = _filterNoQuery(value as Map<String, dynamic>);
  });
}
