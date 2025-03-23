# Angel3 RethinkDB

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_rethinkdb?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/mongo/LICENSE)

This is RethinkDB service for Angel3 framework. RethinkDB is an open-source database for the realtime web.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  angel3_rethink: ^8.0.0
```

`belatuk-rethinkdb` driver will be used for connecting to RethinkDB.

## Usage

This library exposes one class: `RethinkService`. By default, these services will listen to [changefeeds](https://www.rethinkdb.com/docs/changefeeds/ruby/) from the database, which makes them very suitable for WebSocket use. However, only `CREATED`, `UPDATED` and `REMOVED` events will be fired. Technically not
a problem, as it lowers the number of events that need to be handled on the client side.

## Model

`Model` is class with no real functionality; however, it represents a basic document, and your services should host inherited classes. Other Angel service providers host `Model` as well, so you will easily be able to modify your application if you ever switch databases.

```dart
class User extends Model {
  String username;
  String password;
}

main() async {
    var r = RethinkDb();
    var conn = await r.connect(
        db: 'testDB',
        host: "localhost",
        port: 28015,
        user: "admin",
        password: "");

    app.use('/api/users', RethinkService(conn, r.table('users')));
    
    // Add type de/serialization if you want
    app.use('/api/users', TypedService<User>(RethinkService(conn, r.table('users'))));

    // You don't have to even use a table...
    app.use('/api/pro_users', RethinkService(conn, r.table('users').filter({'membership': 'pro'})));
    
    app.service('api/users').afterCreated.listen((event) {
        print("New user: ${event.result}");
    });
}
```

## RethinkService

This class interacts with a `Query` (usually a table) and serializes data to and from Maps.

## RethinkTypedService<T>

Does the same as above, but serializes to and from a target class using `belatuk_json_serializer` and it supports reflection.

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

You can also apply sorting by adding a `reql` parameter on the server-side.

```dart
service.index({'reql': (query) => query.sort(...)});
```

See the tests for more usage examples.
