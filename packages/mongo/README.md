# Angel3 Mongo

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_mongo?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/mongo/LICENSE)

MongoDB-enabled services for the Angel3 framework.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  angel3_mongo: ^8.0.0
```

## Usage

This library exposes one main class: `MongoService`.

## Model

`Model` is class with no real functionality; however, it represents a basic document, and your services should host inherited classes. Other Angel service providers host `Model` as well, so you will easily be able to modify your application if you ever switch databases.

```dart
class User extends Model {
  String username;
  String password;
}

void main() async {
    var db = Db('mongodb://localhost:27017/local');
    await db.open();
    
    var service = app.use('/api/users', MongoService(db.collection("users")));
    
    service.afterCreated.listen((event) {
        print("New user: ${event.result}");
    });
}
```

## MongoService

This class interacts with `DbCollection` (from mongo_dart) and serializing data to and from Maps.

## Querying

You can query these services as follows:

```curl
    /path/to/service?foo=bar
```

The above will query the database to find records where 'foo' equals 'bar'. The former will sort result in ascending order of creation, and so will the latter.

```dart
    List queried = await MyService.index({r"$query": where.id(ObjectId.fromHexString("some hex string"})));
```

And, you can use mongo_dart queries. Just pass it as `query` within `params`.

See the tests for more usage examples.

## **Important Notes**

When connecting to the locally installed instance of MongoDB or docker based MongoDB with authentication enabled, the following connection string is not supported by the MongoDB driver yet.

```dart
  var db = Db('mongodb://<username>:<password>@localhost:27017/local');
  await db.open();
```

Use the following instead.

```dart
  var db = Db('mongodb://localhost:27017/testDB');
  await db.open();
  await db.authenticate("<username>", "<password>", authDb: "admin");
```

* `<username>` is MongoDB username
* `<password>` is MongoDB password
