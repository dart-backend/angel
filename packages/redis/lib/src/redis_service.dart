import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

/// Increments the counter KEYS[1], first seeding it from the pre-10.0.0
/// counter KEYS[2] if KEYS[1] does not exist yet and KEYS[2] holds an integer.
const String _seededIncrScript = '''
if redis.call('EXISTS', KEYS[1]) == 0 then
  local old = redis.pcall('GET', KEYS[2])
  if type(old) == 'string' and string.match(old, '^%-?%d+\$') then
    redis.call('SET', KEYS[1], old)
  end
end
return redis.call('INCR', KEYS[1])
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

  final Random _random = Random();

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

  /// Kept outside the `<prefix>:` namespace, so records of this service cannot
  /// collide with it. Records of a service with no prefix, or with the prefix
  /// `angel_redis`, still can. Without a prefix every key is a possible
  /// record, so [index] skips it explicitly.
  String get _idCounterKey =>
      prefix == null ? 'angel_redis:id' : 'angel_redis:id:$prefix';

  /// The counter key used before 10.0.0.
  String get _legacyIdCounterKey => _applyPrefix('angel_redis:id');

  /// Escapes glob metacharacters so the prefix only matches itself.
  static String _escapeGlob(String s) =>
      s.replaceAllMapped(RegExp(r'[\\*?\[\]]'), (m) => '\\${m[0]}');

  /// Whether [reply] is the error Redis returns for a key holding a hash,
  /// list or other non-string type.
  static bool _isWrongType(RespType reply) =>
      reply.isError && (reply.payload as String).startsWith('WRONGTYPE');

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

  Future<String> _nextId() async {
    var result = await _execute([
      'EVAL',
      _seededIncrScript,
      2,
      _idCounterKey,
      _legacyIdCounterKey,
    ]);
    return result.payload.toString();
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
    var reply = await _tier0.execute(['GET', _applyPrefix(id)]);
    if (reply.isError && !_isWrongType(reply)) {
      throw StateError('Redis GET failed: ${reply.payload}');
    }

    var raw = reply.isError ? null : reply.payload as String?;
    var record = _tryDecode(raw);
    if (record == null) {
      throw AngelHttpException.notFound(message: 'No record found for ID $id');
    }
    return (raw!, record);
  }

  /// Reads the record for [id] and runs [script] with the key, the value that
  /// was read, and the extra arguments returned by [build]. Returns the output
  /// from [build], or tries again after a randomized delay if the record
  /// changed in between.
  Future<T> _compareAndWrite<T>(
    String id,
    String script,
    (List<Object>, T) Function(Map<String, dynamic> record) build,
    String action,
  ) async {
    var key = _applyPrefix(id);

    for (var attempt = 0; attempt < maxWriteAttempts; attempt++) {
      if (attempt > 0) {
        var maxDelay = min(1 << min(attempt, 7), 100);
        await Future.delayed(
          Duration(milliseconds: _random.nextInt(maxDelay) + 1),
        );
      }

      var (current, record) = await _readRecord(id);
      var (extraArgs, output) = build(record);
      var result = await _tier0.execute([
        'EVAL',
        script,
        1,
        key,
        current,
        ...extraArgs,
      ]);
      // The key changed to a non-string type after it was read.
      if (_isWrongType(result)) {
        throw AngelHttpException.notFound(
          message: 'No record found for ID $id',
        );
      }
      if (result.isError) {
        throw StateError('Redis EVAL failed: ${result.payload}');
      }
      if (result.payload == 1) return output;
    }

    throw AngelHttpException.conflict(
      message: 'Record $id changed during $action; try again',
    );
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
      var end = min(i + batchSize, keyList.length);
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
    var givenId = data['id'];

    if (givenId != null) {
      if (!(givenId is String && givenId.isNotEmpty || givenId is int)) {
        throw AngelHttpException.badRequest(
          message: 'ID must be a non-empty string or an integer',
        );
      }
      var id = givenId.toString();
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
      var id = await _nextId();
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
  ]) {
    return _compareAndWrite(id, _compareAndSetScript, (record) {
      var merged = record
        ..addAll(data!)
        ..['id'] = id;
      return ([json.encode(merged)], merged);
    }, 'modification');
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
  ]) {
    return _compareAndWrite(
      id,
      _compareAndDeleteScript,
      (record) => (const [], record),
      'removal',
    );
  }
}
