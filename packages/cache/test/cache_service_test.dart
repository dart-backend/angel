import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

void main() {
  late MapService database, cache;
  late CacheService<String?, Map<String, dynamic>> service;

  setUp(() async {
    database = MapService();
    cache = MapService();
    // ignoreParams, so reads without params can be served from the cache.
    service = CacheService(
      database: database,
      cache: cache,
      ignoreParams: true,
    );
    await database.create({'text': 'first'});
    await database.create({'text': 'second'});
  });

  test('read stores a cache miss under the same id', () async {
    expect((await service.read('1'))['text'], 'second');

    // Cached at id '1', not under a newly generated id.
    expect((await cache.read('1'))['text'], 'second');
    expect(cache.items, hasLength(1));
  });

  test('a second read is served from the cache', () async {
    await service.read('1');
    database.items.clear();
    expect((await service.read('1'))['text'], 'second');
  });
}
