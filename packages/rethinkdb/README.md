# Angel3 RethinkDB

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_rethinkdb?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/rethinkdb/LICENSE)

This is RethinkDB service for Angel3 framework. RethinkDB is an open-source database for the realtime web.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  angel3_rethinkdb: ^10.0.0
```

`belatuk-rethinkdb` driver will be used for connecting to RethinkDB.

## Usage

This library exposes one class: `RethinkService`. It interacts with a query (usually a table) and serializes data to and from Maps. It does not need reflection, so an app using it can be created without a `reflector` and compiled with `dart compile exe`.

By default, these services listen to [changefeeds](https://rethinkdb.com/docs/changefeeds/) from the database, which makes them very suitable for WebSocket use. A change made to the table by anyone fires `afterCreated`, `afterUpdated` or `afterRemoved` on the `HookedService` the service is mounted as. Pass `listenForChanges: false` to turn this off.

```dart
void main() async {
  var r = RethinkDb();
  var conn = await r.connect(
    db: 'testDB',
    host: "localhost",
    port: 28015,
    user: "admin",
    password: "",
  );

  var app = Angel();
  app.use('/api/users', RethinkService(conn, r.table('users')));

  // You don't have to even use a table...
  app.use(
    '/api/pro_users',
    RethinkService(conn, r.table('users').filter({'membership': 'pro'})),
  );

  app.findHookedService('api/users')!.afterCreated.listen((event) {
    print("New user: ${event.result}");
  });
}
```

Wrap the service in a `TypedService` from `angel3_framework` to serialize to and from a class.

`read`, `modify`, `update` and `remove` act on the record whose id is in the path; an `id` in the body cannot change it. `update` of a missing id creates the record, and `modify` of one is a 404. A write that RethinkDB rejects is a 409 for a duplicate id, and a 400 otherwise.

## Querying

You can query these services as follows:

```curl
    /path/to/service?foo=bar
```

The above will query the database to find records where `foo` equals `bar`. The former will sort result in ascending order of creation, and so will the latter.

You can use advanced queries:

```dart
// Pass an actual query...
service.index({'query': r.table('foo').filter(...)});

// Or, a function that creates a query from a table...
service.index({'query': (table) => table.getAll('foo')});

// Or, a Map, which will be transformed into a `filter` query:
service.index({'query': {'foo': 'bar', 'baz': 'quux'}});
```

The query applies to `index`, and to `remove` with a `null` id, which removes every matching record (clients may only do that if `allowRemoveAll` is `true`). It is ignored by `read`, `modify`, `update` and `remove` of one record, so it cannot make them reach other records.

You can also apply sorting by adding a `reql` parameter on the server-side.

```dart
service.index({'reql': (query) => query.sort(...)});
```

See the tests for more usage examples.
