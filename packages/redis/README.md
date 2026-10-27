# Angel3 Redis

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_redis?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/redis/LICENSE)

**Forked from `angel_redis` to support NNBD**

Redis-enabled services for the Angel3 framework. `RedisService` can be used alone, *or* as the backend of a [`CacheService`](https://pub.dev/packages/angel3_cache), and thereby cache the results of calling an upstream database.

## Installation

`package:angel3_redis` requires Angel3.

In your `pubspec.yaml`:

```yaml
dependencies:
    angel3_framework: ^10.0.0
    angel3_redis: ^10.0.0
```

## Usage

Pass an instance of `RespCommandsTier2` (from `package:resp_client`) to the `RedisService` constructor. You can also pass an optional prefix, which is recommended if you are using `angel3_redis` for multiple logically-separate collections. Redis is a flat key-value store; by prefixing the keys used, `angel3_redis` can provide the experience of using separate stores, rather than a single node.

Without a prefix, there's a chance that different collections can overwrite one another's data.

### Example

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

## Notes

* `angel3_redis` stores each record as a JSON string, not as a Redis hash. Keys that hold anything other than a JSON object are not records: `index` skips them, and `read`, `modify` and `remove` return 404 for them.
* Prefixes must not nest. `index` on prefix `app` also returns the records of a service with prefix `app:users`. Without a prefix, `index` scans the whole database.
* `index` uses `SCAN` and `MGET` in batches of `batchSize` keys (default 1000), so it does not block the Redis server, but it still reads every record in the collection.
* `modify` and `remove` are atomic. They read the record, then write only if it has not changed in the meantime, trying up to `maxWriteAttempts` times (default 10). If the record keeps changing, they return 409.
* Prefer `update` to `modify` when you have the whole record. It performs one query and overwrites the stored record.
* `create` keeps an `id` you supply, for example the primary key of a row you are caching from another database. The `id` must be a non-empty string or an integer, otherwise `create` returns 400. If a record with that `id` already exists, `create` returns 409 instead of overwriting it.
* Without an `id`, `create` generates one by incrementing the counter `angel_redis:id:<prefix>` (`angel_redis:id` without a prefix), skipping IDs that are already taken. On a database used with 9.x, the counter continues from the old `<prefix>:angel_redis:id` key, which is left in place.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`create`** throws a `409` if a record of the id already exists, and a `400` unless the id is a non-empty string or an integer. Use `update` to replace a record.
* **`modify` and `remove`** throw a `409` if the record keeps changing during their writes (`maxWriteAttempts`).
* **`read`, `modify` and `remove`** throw a `404` for keys that do not hold a JSON object.
