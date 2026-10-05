# Angel3 HTTP Cache

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_cache?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/cache/LICENSE)

A service that provides HTTP caching to the response data for [Angel3 framework](https://pub.dev/packages/angel3).

## `CacheService`

A `Service` class that caches data from one service, storing it in another. An imaginable use case is storing results from MongoDB or another database in Memcache/Redis.

## `cacheSerializationResults`

A middleware that enables the caching of response serialization.

This can improve the performance of sending objects that are complex to serialize and are returned again and again, such as a precomputed list. Results are cached per object instance across requests (held weakly, so objects can still be garbage-collected). Pass a `shouldCache` callback to decide which values may be cached, and a `timeout` for objects that can change:

```dart
app.fallback(cacheSerializationResults(
  timeout: const Duration(minutes: 5),
  shouldCache: (req, res, value) => value is List,
));
```

```dart
void main() async {
    var app = Angel()..lazyParseBodies = true;
    
    app.use(
      '/api/todos',
      CacheService(
        database: AnonymousService(
          index: ([params]) {
            print('Fetched directly from the underlying service at ${DateTime.now()}!');
            return ['foo', 'bar', 'baz'];
          },
          read: (id, [params]) {
            return {id: '$id at ${DateTime.now()}'};
          }
        ),
      ),
    );
}
```

## `ResponseCache`

A flexible response cache for Angel3.

Use this to improve real and perceived response of Web applications, as well as to memorize expensive responses.

Supports the `If-Modified-Since` header, as well as storing the contents of response buffers in memory.

`handleRequest` buffers responses for matching paths, so handlers need no changes. Clients whose copy is still current get `304 Not Modified`. Only responses that are safe to share are stored: status 200, no cookies, and not marked `Cache-Control: no-store` or `private`. Requests carrying an `Authorization` header bypass the cache entirely. At most `maxEntries` responses (1024 by default) are kept; when full, expired entries are dropped first, then the least recently used.

To initialize a simple cache:

```dart
Future configureServer(Angel app) async {
  // Simple instance.
  var cache = ResponseCache();
  
  // You can also pass an invalidation timeout.
  var cache = ResponseCache(timeout: const Duration(days: 2));
  
  // Close the cache when the application closes.
  app.shutdownHooks.add((_) => cache.close());
  
  // Use `patterns` to specify which resources should be cached.
  cache.patterns.addAll([
    'robots.txt',
    RegExp(r'\.(png|jpg|gif|txt)$'),
    Glob('public/**/*'),
  ]);
  
  // REQUIRED: The middleware that serves cached responses
  app.use(cache.handleRequest);
  
  // REQUIRED: The response finalizer that saves responses to the cache
  app.responseFinalizers.add(cache.responseFinalizer);
}
```

### Purging the Cache

Call `invalidate` to remove a resource from a `ResponseCache`.

Some servers expect a reverse proxy or caching layer to support `PURGE` requests. If this is your case, make sure to include some sort of validation (maybe IP-based) to ensure no arbitrary attacker can hack your cache:

```dart
Future configureServer(Angel app) async {
  app.addRoute('PURGE', '*', (req, res) {
    if (req.ip != '127.0.0.1')
      throw AngelHttpException.forbidden();
    return cache.purge(req.uri.path);
  });
}
```
