# Angel3 HTTP Cache

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_cache?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/cache/LICENSE)

A service that provides HTTP caching to the response data for [Angel3 framework](https://pub.dev/packages/angel3).

## `CacheService`

A `Service` class that caches data from one service (`database`), storing it in another (`cache`). An imaginable use case is storing results from MongoDB or another database in Memcache/Redis.

```dart
void main() async {
  var app = Angel();

  app.use(
    '/api/todos',
    CacheService(
      // Any fast service works; a MapService keeps the cache in memory.
      cache: MapService(),
      database: AnonymousService(
        index: ([params]) async {
          print('Fetched directly from the underlying service at ${DateTime.now()}!');
          return ['foo', 'bar', 'baz'];
        },
        read: (id, [params]) async {
          return {id: '$id at ${DateTime.now()}'};
        },
      ),
      timeout: const Duration(minutes: 10),
    ),
  );
}
```

- Cached results expire after `timeout` (10 minutes by default).
- A cached read is reused only for the same query (`params['query']`); set `ignoreParams: true` to reuse it regardless.
- `modify` and `update` write the new record through to `cache`, and `remove` evicts it, so several instances can share one cache.
- If `cache` fails, reads fall back to `database`.

## `cacheSerializationResults`

A middleware that enables the caching of response serialization.

This can improve the performance of sending objects that are complex to serialize and are returned again and again, such as a precomputed list. Results are cached per object instance across requests (held weakly, so objects can still be garbage-collected). Pass a `shouldCache` callback to decide which values may be cached, and a `timeout` for objects that can change:

```dart
app.fallback(cacheSerializationResults(
  timeout: const Duration(minutes: 5),
  shouldCache: (req, res, value) => value is List,
));
```

## `ResponseCache`

A flexible response cache for Angel3.

Use this to improve real and perceived response of Web applications, as well as to memorize expensive responses.

Supports the `If-Modified-Since` header, as well as storing the contents of responses in memory.

`handleRequest` buffers responses for matching paths, so handlers need no changes. Clients whose copy is still current get `304 Not Modified`. Only responses that are safe to share are stored: status 200, no cookies, and not marked `Cache-Control: no-store` or `private`. Requests carrying an `Authorization` header bypass the cache entirely. At most `maxEntries` responses (1024 by default) are kept; when full, expired entries are dropped first, then the least recently used.

To initialize a simple cache:

```dart
Future configureServer(Angel app) async {
  // Responses expire after `timeout` (10 minutes by default).
  var cache = ResponseCache(timeout: const Duration(days: 2));

  // Close the cache when the application closes.
  app.shutdownHooks.add((_) => cache.close());

  // Use `patterns` (any `Pattern`, such as a `String` or `RegExp`) to specify
  // which request paths should be cached.
  cache.patterns.addAll([
    '/robots.txt',
    RegExp(r'\.(png|jpg|gif|txt)$'),
    RegExp(r'^/public/'),
  ]);

  // REQUIRED: The middleware that serves cached responses
  app.fallback(cache.handleRequest);

  // REQUIRED: The response finalizer that saves responses to the cache
  app.responseFinalizers.add(cache.responseFinalizer);
}
```

The cache key is the request URI including its query string. Pass `ignoreQueryAndFragment: true` to cache by path only.

### Purging the Cache

Call `purge` with a cache key to remove a resource from a `ResponseCache`.

Some servers expect a reverse proxy or caching layer to support `PURGE` requests. If this is your case, make sure to include some sort of validation (maybe IP-based) to ensure no arbitrary attacker can hack your cache:

```dart
Future configureServer(Angel app, ResponseCache cache) async {
  app.addRoute('PURGE', '*', (req, res) {
    if (req.ip != '127.0.0.1') {
      throw AngelHttpException.forbidden();
    }
    // Keys include the query string unless `ignoreQueryAndFragment` is set.
    cache.purge(req.uri.toString());
  });
}
```
