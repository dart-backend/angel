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
  angel3_sembast: ^8.0.0
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

The above will query the database to find records where 'foo' equals 'bar'.

The former will sort result in ascending order of creation, and so will the latter.

```dart
List queried = await MyService.index({r"query": where.id(Finder(filter: Filter(...))));
```

Of course, you can use `package:sembast` queries. Just pass it as `query` within `params`.

See the tests for more usage examples.
