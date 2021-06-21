# Angel3 Redis

[![version](https://img.shields.io/badge/pub-v2.0.1-brightgreen)](https://pub.dartlang.org/packages/angel3_redis)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/redis/LICENSE)

**Forked from `angel_redis` to support NNBD**

Redis-enabled services for the Angel3 framework. `RedisService` can be used alone, *or* as the backend of a [`CacheService`](https://pub.dev/packages/angel3_cache), and thereby cache the results of calling an upstream database.

## Installation

`package:angel3_redis` requires Angel3.

In your `pubspec.yaml`:

```yaml
dependencies:
    angel3_framework: ^4.0.0
    angel3_redis: ^2.0.0
```

## Usage

Pass an instance of `RespCommandsTier2` (from `package:resp_client`) to the `RedisService` constructor. You can also pass an optional prefix, which is recommended if you are using `angel3_redis` for multiple logically-separate collections. Redis is a flat key-value store; by prefixing the keys used, `angel3_redis` can provide the experience of using separate stores, rather than a single node.

Without a prefix, there's a chance that different collections can overwrite one another's data.

## Notes

* Neither `index`, nor `modify` is atomic; each performs two separate queries.`angel3_redis` stores data as JSON strings, rather than as Redis hashes, so an update-in-place is impossible.
* `index` uses Redis' `KEYS` functionality, so use it sparingly in production, if at all. In a larger database, it can quickly
become a bottleneck.
* `remove` uses `MULTI`+`EXEC` in a transaction.
* Prefer using `update`, rather than `modify`. The former only performs one query, though it does overwrite the current
contents for a given key.
* When calling `create`, it's possible that you may already have an `id` in mind to insert into the store. For example,
when caching another database, you'll preserve the ID or primary key of an item. `angel3_redis` heeds this. If no
`id` is present, then an ID will be created via an `INCR` call.

## Example

Also present at `example/main.dart`:

```dart
import 'package:angel3_redis/angel3_redis.dart';
import 'package:resp_client/resp_client.dart';
import 'package:resp_client/resp_commands.dart';
import 'package:resp_client/resp_server.dart';

main() async {
  var connection = await connectSocket('localhost');
  var client = RespClient(connection);
  var service = RedisService(RespCommandsTier2(client), prefix: 'example');

  // Create an object
  await service.create({'id': 'a', 'hello': 'world'});

  // Read it...
  var read = await service.read('a');
  print(read['hello']);

  // Delete it.
  await service.remove('a');

  // Close the connection.
  await connection.close();
}
```
