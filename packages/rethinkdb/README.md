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

## CRUD

On the server, call the service directly:

```dart
var todos = RethinkService(conn, r.table('todos'));
app.use('/todos', todos);

// Create: RethinkDB generates the id unless the data has one.
var todo = await todos.create({'title': 'Clean your room', 'completed': false});
var id = todo['id'] as String;

// Read one record, or all of them.
todo = await todos.read(id);
var all = await todos.index();
var open = await todos.index({
  'query': {'completed': false},
});

// Modify (a patch): changes only the given fields.
todo = await todos.modify(id, {'completed': true});

// Update (a replace): the record becomes the given data.
todo = await todos.update(id, {'title': 'Clean the kitchen', 'completed': false});

// Remove one record, which is returned.
var removed = await todos.remove(id);
```

Over HTTP, the same calls are:

| Request | Call |
| --- | --- |
| `GET /todos` | `index()`, with the query string as the `query` (see [Querying](#querying)) |
| `GET /todos/:id` | `read(id)` |
| `POST /todos` | `create(body)` |
| `PATCH /todos/:id` | `modify(id, body)` |
| `PUT /todos/:id` or `POST /todos/:id` | `update(id, body)` |
| `DELETE /todos/:id` | `remove(id)` |
| `DELETE /todos` | `remove(null)`, which removes every matching record; a 403 unless `allowRemoveAll` is `true` |

`read`, `modify`, `update` and `remove` act on the record whose id is in the path; an `id` in the body cannot change it. `read`, `modify` and `remove` of a missing id are a 404, and `update` of one creates the record. A write that RethinkDB rejects is a 409 for a duplicate id, and a 400 otherwise.

`create` needs a service over a table; on a service over another query, it is a 405.

## Querying

You can query these services as follows:

```curl
    /path/to/service?foo=bar
```

The above will query the database to find records where `foo` equals `bar`. Pass `allowQuery: false` to ignore a `query` Map, such as the query string.

The values of a query string are strings: `?completed=false` matches records whose `completed` is the string `'false'`, not the boolean. To filter on another type, pass a `query` Map with that value on the server.

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

You can also extend the query, e.g. to sort it, by adding a `reql` parameter on the server-side. It is applied after `query`.

```dart
service.index({'reql': (query) => query.orderBy('title')});
```

See the tests for more usage examples.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **One record**: `read`, `modify`, `update` and `remove` of one record ignore `query`, which could make them reach every record it matched.
* **Ids**: `modify` and `update` act on the id in the path, not an `id` in the body. `modify` of a missing id is a `404`, and `update` creates it.
* **Driver**: requires `belatuk_rethinkdb` 2.0.0. A query on a closed connection throws an `RqlDriverError`, and the queries waiting for a reply fail when the connection closes; see its changelog.
