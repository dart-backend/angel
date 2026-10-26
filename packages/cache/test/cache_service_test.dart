import 'dart:async';

import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

/// A [MapService] that counts reads, to tell cache hits from database reads.
class CountingService extends MapService {
  int reads = 0;

  CountingService() : super(autoIdAndDateFields: false);

  @override
  Future<Map<String, dynamic>> read(String? id, [Map<String, dynamic>? p]) {
    reads++;
    return super.read(id, p);
  }
}

/// A database whose next read, index or write waits to be released.
class SlowService extends MapService {
  Completer<void>? hold, holdIndex, holdWrite;

  SlowService() : super(autoIdAndDateFields: false);

  @override
  Future<List<Map<String, dynamic>>> index([Map<String, dynamic>? p]) {
    var result = super.index(p);
    var wait = holdIndex?.future ?? Future.value();
    holdIndex = null;
    return wait.then((_) => result);
  }

  @override
  Future<Map<String, dynamic>> modify(
    String? id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? p,
  ]) async {
    // Not written until released.
    var wait = holdWrite?.future;
    holdWrite = null;
    if (wait != null) await wait;
    return super.modify(id, data, p);
  }

  @override
  Future<Map<String, dynamic>> read(String? id, [Map<String, dynamic>? p]) {
    // Read now, returned once released: the version before a later write.
    var result = super.read(id, p);
    var wait = hold?.future ?? Future.value();
    hold = null;
    return wait.then((_) => result);
  }
}

/// A cache layer that is down.
class BrokenCache extends Service<String?, Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> read(String? id, [Map<String, dynamic>? p]) =>
      Future.error(StateError('cache down'));

  @override
  Future<Map<String, dynamic>> update(
    String? id,
    Map<String, dynamic> data, [
    Map<String, dynamic>? p,
  ]) => Future.error(StateError('cache down'));

  @override
  Future<Map<String, dynamic>> remove(String? id, [Map<String, dynamic>? p]) =>
      Future.error(StateError('cache down'));
}

void main() {
  late CountingService database;
  late MapService cache;

  CacheService<String?, Map<String, dynamic>> cached({
    Service<String?, Map<String, dynamic>>? cacheLayer,
    bool ignoreParams = true,
  }) => CacheService(
    database: database,
    cache: cacheLayer ?? cache,
    ignoreParams: ignoreParams,
  );

  setUp(() async {
    database = CountingService();
    cache = MapService();
    await database.create({'id': '0', 'text': 'first'});
    await database.create({'id': '1', 'text': 'second'});
    database.reads = 0;
  });

  group('read', () {
    test('stores a cache miss under the same id', () async {
      var service = cached();
      expect((await service.read('1'))['text'], 'second');
      expect((await cache.read('1'))['text'], 'second');
      expect(cache.items, hasLength(1));
    });

    test('a second read is served from the cache', () async {
      var service = cached();
      await service.read('1');
      await service.read('1');
      expect(database.reads, 1);
    });

    test('uses the cache for reads without params', () async {
      var service = cached(ignoreParams: false);
      await service.read('1');
      await service.read('1');
      expect(database.reads, 1);
    });

    test('accepts params without a query', () async {
      var service = cached(ignoreParams: false);
      await service.read('1', {'x': 1});
      expect((await service.read('1', {'x': 1}))['text'], 'second');
      expect(database.reads, 1);
    });

    test('a different query bypasses the cache', () async {
      var service = cached(ignoreParams: false);
      await service.read('1', {
        'query': {'a': '1'},
      });
      await service.read('1', {
        'query': {'a': '2'},
      });
      expect(database.reads, 2);
    });

    test('falls back to the database when the cache is down', () async {
      var service = cached(cacheLayer: BrokenCache());
      expect((await service.read('1'))['text'], 'second');
      expect((await service.read('1'))['text'], 'second');
    });
  });

  group('writes', () {
    test('update replaces the record (database.update)', () async {
      var service = cached();
      var result = await service.update('0', {'id': '0', 'other': true});
      expect(result, {'id': '0', 'other': true});
      expect(await database.read('0'), {'id': '0', 'other': true});
    });

    test('modify merges into the record (database.modify)', () async {
      var service = cached();
      var result = await service.modify('0', {'extra': 1});
      expect(result, {'id': '0', 'text': 'first', 'extra': 1});
    });

    test('other instances sharing the cache see a modify', () async {
      var a = cached(), b = cached();
      await b.read('0');
      await a.modify('0', {'text': 'changed'});
      expect((await b.read('0'))['text'], 'changed');
    });

    test('other instances sharing the cache see an update', () async {
      var a = cached(), b = cached();
      await b.read('0');
      await a.update('0', {'id': '0', 'text': 'replaced'});
      expect((await b.read('0'))['text'], 'replaced');
    });

    test('remove evicts the record from the shared cache', () async {
      var a = cached(), b = cached();
      await b.read('0');
      await a.remove('0');
      expect(cache.items.any((i) => i['id'] == '0'), isFalse);
      await expectLater(
        b.read('0'),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('a cache that is down does not fail writes', () async {
      var service = cached(cacheLayer: BrokenCache());
      expect((await service.modify('0', {'x': 1}))['x'], 1);
      expect((await service.update('1', {'id': '1'}))['id'], '1');
      expect((await service.remove('1'))['id'], '1');
    });
  });

  test('a read overlapping a write does not store the old version', () async {
    var slow = SlowService();
    await slow.create({'id': '1', 'text': 'v1'});
    var shared = MapService(autoIdAndDateFields: false);
    var service = CacheService<String?, Map<String, dynamic>>(
      database: slow,
      cache: shared,
      ignoreParams: true,
    );

    var release = slow.hold = Completer<void>();
    var read = service.read('1');
    await service.modify('1', {'text': 'v2'});
    release.complete();
    expect((await read)['text'], 'v1');

    // The shared cache keeps the version of the write.
    expect((await shared.read('1'))['text'], 'v2');
    expect((await service.read('1'))['text'], 'v2');
  });

  test('index returns a list the caller may change', () async {
    var service = cached();
    (await service.index()).clear();
    expect(await service.index(), hasLength(2));
  });

  test('a read during a write does not store the old version', () async {
    var slow = SlowService();
    await slow.create({'id': '1', 'text': 'v1'});
    var shared = MapService(autoIdAndDateFields: false);
    var service = CacheService<String?, Map<String, dynamic>>(
      database: slow,
      cache: shared,
      ignoreParams: true,
    );

    // The write starts, then a read gets v1 from the database, which the
    // write has not changed yet; the read is held until the write is done.
    var releaseWrite = slow.holdWrite = Completer<void>();
    var write = service.modify('1', {'text': 'v2'});
    var releaseRead = slow.hold = Completer<void>();
    var read = service.read('1');
    releaseWrite.complete();
    await write;
    releaseRead.complete();
    expect((await read)['text'], 'v1');

    expect((await shared.read('1'))['text'], 'v2');
    expect((await service.read('1'))['text'], 'v2');
  });

  test('an index overlapping a write is not stored', () async {
    var slow = SlowService();
    await slow.create({'id': '1', 'text': 'v1'});
    var service = CacheService<String?, Map<String, dynamic>>(
      database: slow,
      cache: MapService(autoIdAndDateFields: false),
      ignoreParams: true,
    );

    var release = slow.holdIndex = Completer<void>();
    var index = service.index();
    await service.create({'id': '2', 'text': 'new'});
    release.complete();
    expect(await index, hasLength(1));

    expect(await service.index(), hasLength(2));
  });
}
