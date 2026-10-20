import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:resp_client/resp_client.dart';
import 'package:resp_client/resp_commands.dart';

/// Deletes a key only if its current value is still ARGV[1].
const String _compareAndDeleteScript = '''
if redis.call('GET', KEYS[1]) == ARGV[1] then
  redis.call('DEL', KEYS[1])
  return 1
end
return 0
''';

/// Sets a key to ARGV[2] only if its current value is still ARGV[1].
const String _compareAndSetScript = '''
if redis.call('GET', KEYS[1]) == ARGV[1] then
  redis.call('SET', KEYS[1], ARGV[2])
  return 1
end
return 0
''';

/// An Angel service that reads and writes JSON within a Redis store.
class RedisService extends Service<String, Map<String, dynamic>> {
  final RespCommandsTier2 respCommands;

  /// An optional string prefixed to keys before they are inserted into Redis.
  ///
  /// Consider using this if you are using several different Redis collections
  /// within a single application. Without a prefix, [index] scans the whole
  /// database and returns every string value that holds a JSON object.
  ///
  /// Prefixes must not nest: [index] on prefix `app` also returns the records
  /// of a service with prefix `app:users`.
  final String? prefix;

  /// The number of keys requested per `SCAN` and `MGET` call in [index].
  final int batchSize;

  /// The number of times [modify] and [remove] try when the record changes
  /// between reading and writing it.
  final int maxWriteAttempts;

  RedisService(
    this.respCommands, {
    this.prefix,
    this.batchSize = 1000,
    this.maxWriteAttempts = 10,
  }) {
    if (batchSize < 1) {
      throw RangeError.range(batchSize, 1, null, 'batchSize');
    }
    if (maxWriteAttempts < 1) {
      throw RangeError.range(maxWriteAttempts, 1, null, 'maxWriteAttempts');
    }
  }

  RespCommandsTier0 get _tier0 => respCommands.tier1.tier0;

  String _applyPrefix(String id) => prefix == null ? id : '$prefix:$id';

  /// Kept outside the `<prefix>:` namespace so that no record ID can collide
  /// with it. Without a prefix every key is a possible record, so [index]
  /// skips it explicitly.
  String get _idCounterKey =>
      prefix == null ? 'angel_redis:id' : 'angel_redis:id:$prefix';

  /// Escapes glob metacharacters so the prefix only matches itself.
  static String _escapeGlob(String s) =>
      s.replaceAllMapped(RegExp(r'[\\*?\[\]]'), (m) => '\\${m[0]}');

  Future<RespType> _execute(List<Object?> command) async {
    var result = await _tier0.execute(command);
    if (result.isError) {
      throw StateError('Redis ${command.first} failed: ${result.payload}');
    }
    return result;
  }

  /// Returns `false` if [key] already exists. Unlike [RespCommandsTier2.set],
  /// a Redis error throws rather than being reported as `false`.
  Future<bool> _setIfAbsent(String key, String value) async {
    var result = await _execute(['SET', key, value, 'NX']);
    return result.payload != null;
  }

  Map<String, dynamic>? _tryDecode(String? value) {
    if (value == null) return null;
    try {
      var decoded = json.decode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Returns the raw value and decoded record for [id]. Throws a 404 if the
  /// key is missing or does not hold a JSON object.
  Future<(String, Map<String, dynamic>)> _readRecord(String id) async {
    var raw = await respCommands.get(_applyPrefix(id));
    var record = _tryDecode(raw);
    if (record == null) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    }
    return (raw!, record);
  }

  @override
  Future<List<Map<String, dynamic>>> index([
    Map<String, dynamic>? params,
  ]) async {
    var pattern = prefix == null ? '*' : '${_escapeGlob(prefix!)}:*';
    var keys = <String>{};
    var cursor = 0;

    // SCAN may return a key more than once, hence the set.
    do {
      var result = await respCommands.scan(
        cursor,
        pattern: pattern,
        count: batchSize,
      );
      keys.addAll(result.keys);
      cursor = result.cursor;
    } while (cursor != 0);

    keys.remove(_idCounterKey);
    if (keys.isEmpty) return [];

    var output = <Map<String, dynamic>>[];
    var keyList = keys.toList();

    for (var i = 0; i < keyList.length; i += batchSize) {
      var end = i + batchSize < keyList.length ? i + batchSize : keyList.length;
      var result = await _execute(['MGET', ...keyList.sublist(i, end)]);

      // MGET returns nil for keys that were deleted after the scan or that
      // hold a non-string type. Values that are not JSON objects are skipped.
      for (var value in result.toArray().payload ?? const <RespType>[]) {
        var record = _tryDecode(value.payload as String?);
        if (record != null) output.add(record);
      }
    }

    return output;
  }

  @override
  Future<Map<String, dynamic>> read(
    String id, [
    Map<String, dynamic>? params,
  ]) async {
    var (_, record) = await _readRecord(id);
    return record;
  }

  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic>? data, [
    Map<String, dynamic>? params,
  ]) async {
    data = Map<String, dynamic>.from(data!);

    if (data['id'] != null) {
      var id = data['id'].toString();
      data['id'] = id;
      if (!await _setIfAbsent(_applyPrefix(id), json.encode(data))) {
        throw AngelHttpException.conflict(
          message: 'A record with ID $id already exists',
        );
      }
      return data;
    }

    // Generated IDs can collide with client-supplied ones, so skip any that
    // are already taken.
    while (true) {
      var counter = await _execute(['INCR', _idCounterKey]);
      var id = counter.payload.toString();
      data['id'] = id;
      if (await _setIfAbsent(_applyPrefix(id), json.encode(data))) {
        return data;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> modify(
    String id,
    Map<String, dynamic>? data, [
    Map<String, dynamic>? params,
  ]) async {
    var key = _applyPrefix(id);

    for (var attempt = 0; attempt < maxWriteAttempts; attempt++) {
      var (current, record) = await _readRecord(id);
      var merged = record
        ..addAll(data!)
        ..['id'] = id;

      var result = await _execute([
        'EVAL',
        _compareAndSetScript,
        1,
        key,
        current,
        json.encode(merged),
      ]);
      if (result.payload == 1) return merged;
    }

    throw AngelHttpException.conflict(
      message: 'Record $id changed during modification; try again',
    );
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic>? data, [
    Map<String, dynamic>? params,
  ]) async {
    data = Map<String, dynamic>.from(data!)..['id'] = id;
    await _execute(['SET', _applyPrefix(id), json.encode(data)]);
    return data;
  }

  @override
  Future<Map<String, dynamic>> remove(
    String id, [
    Map<String, dynamic>? params,
  ]) async {
    var key = _applyPrefix(id);

    for (var attempt = 0; attempt < maxWriteAttempts; attempt++) {
      var (current, record) = await _readRecord(id);
      var result = await _execute([
        'EVAL',
        _compareAndDeleteScript,
        1,
        key,
        current,
      ]);
      if (result.payload == 1) return record;
    }

    throw AngelHttpException.conflict(
      message: 'Record $id changed during removal; try again',
    );
  }
}
