# Angel3 Mongo

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_mongo?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/mongo/LICENSE)

MongoDB-enabled services for the Angel3 framework.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  angel3_mongo: ^10.0.0
```

## Usage

This library exposes one main class: `MongoService`. It interacts with a `DbCollection` (from mongo_dart) and serializes data to and from Maps. It does not need reflection, so an app using it can be created without a `reflector` and compiled with `dart compile exe`.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mongo/angel3_mongo.dart';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  var db = Db('mongodb://localhost:27017/testDB');
  await db.open();
  await db.authenticate("<username>", "<password>", authDb: "admin");

  var app = Angel();
  var service = app.use('/api/users', MongoService(db.collection('users')));

  service.afterCreated.listen((event) {
    print("New user: ${event.result}");
  });

  await AngelHttp(app).startServer('127.0.0.1', 3000);
}
```

Wrap the service in a `TypedService` from `angel3_framework` to serialize to and from a class.

The service manages each document's id and its `createdAt` and `updatedAt` timestamps, so clients cannot set them. Ids are MongoDB `ObjectId`s, sent to clients as hex strings in `id`; a malformed id is a 400 and a missing one a 404. `modify` merges the data into the document, and `update` replaces it, creating it if missing.

## Querying

You can query these services as follows:

```curl
    /path/to/service?foo=bar
```

The above will query the database to find records where `foo` equals `bar`. Two keys are not filters:

* `$sort` sorts by one or more fields, separated by commas; a field starting with `-` sorts descending. For example, `?$sort=-createdAt` lists the newest first, and `?$sort=rank,-to` sorts by `rank`, then by `to` descending.
* `$limit` returns at most that many records, e.g. `?$sort=-createdAt&$limit=10`.

The other keys the framework reserves (`page` and `token`) are ignored. Pass `allowQuery: false` to ignore all of this in queries from clients.

On the server, you can also pass a mongo_dart query as `query`, and sort with `$sort`:

```dart
var queried = await service.index({'query': where.eq('foo', 'bar')});
var newestFirst = await service.index({r'$sort': {'createdAt': -1}});
```

See the tests for more usage examples.

## **Important Notes**

When connecting to a locally installed instance of MongoDB or docker based MongoDB with authentication enabled, the following connection string is not supported yet.

```dart
  var db = Db('mongodb://<username>:<password>@localhost:27017/testDB');
  await db.open();
```

Use the following instead. By default the user access information is stored in `admin` database.

```dart
  var db = Db('mongodb://localhost:27017/testDB');
  await db.open();
  await db.authenticate("<username>", "<password>", authDb: "admin");
```

Where

* `<username>` is MongoDB username
* `<password>` is MongoDB password

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Missing ids**: `modify` and `remove` of a missing id are a `404`, instead of creating a document, or answering `{"id": null}`. Use `update` to create a document of a given id.
