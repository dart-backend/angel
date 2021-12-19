# Angel3 HTTP Cache

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_cache?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/cache/LICENSE)

A service that provides HTTP caching to the response data for [Angel3 framework](https://pub.dev/packages/angel3).

## `CacheService`

A `Service` class that caches data from one service, storing it in another. An imaginable use case is storing results from MongoDB or another database in Memcache/Redis.

## `cacheSerializationResults`

A middleware that enables the caching of response serialization.

This can improve the performance of sending objects that are complex to serialize. You can pass a [shouldCache] callback to determine which values should be cached.

```dart
void main() async {
    var app = Angel()..lazyParseBodies = true;
    
    app.use(
      '/api/todos',
      CacheService(
        database: AnonymousService(
          index: ([params]) {
            print('Fetched directly from the underlying service at ${new DateTime.now()}!');
            return ['foo', 'bar', 'baz'];
          },
          read: (id, [params]) {
            return {id: '$id at ${new DateTime.now()}'};
          }
        ),
      ),
    );
}
```

## `ResponseCache`

A flexible response cache for Angel3.

Use this to improve real and perceived response of Web applications, as well as to memoize expensive responses.

Supports the `If-Modified-Since` header, as well as storing the contents of response buffers in memory.

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
