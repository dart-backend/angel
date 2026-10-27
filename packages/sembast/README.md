# Sembast Persistent Service for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_sembast?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/sembast/LICENSE)

A plugin service that persist data to Sembast for Angel3 framework.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  angel3_sembast: ^10.0.0
```

## Usage

This library exposes one main class: `SembastService`.

### SembastService

This class interacts with a `Database` and `Store` (from `package:sembast`) and serializes data to and from Maps.

### Querying

You can query these services as follows:

```curl
/path/to/service?foo=bar
```

The above will query the database to find records where 'foo' equals 'bar'. A record must match every field of the query, and `id` matches the key of the record.

Sort with `$sort`: a field name sorts by it in ascending order, and a map of field names to `1` (ascending) or `-1` (descending) sorts by each of them:

```curl
/path/to/service?$sort=name
```

```dart
await service.index({r'$sort': {'name': -1}});
```

Removing all records (with `allowRemoveAll`, or on the server side) removes only those that match the query, if there is one.

Of course, you can use `package:sembast` queries. Just pass a `Finder` as `query` within `params`:

```dart
var queried = await service.index({
  'query': Finder(filter: Filter.equals('foo', 'bar')),
});
```

See the tests for more usage examples.
