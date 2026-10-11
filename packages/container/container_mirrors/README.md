# Angel3 Container Mirrors

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container_mirrors?include_prereleases)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/container/container_mirrors/LICENSE)

`MirrorsReflector`, a `dart:mirrors` backend for [`angel3_container`](https://pub.dev/packages/angel3_container). With it, the container can construct classes that are not registered, and Angel3 can use controllers and `ioc()` handlers.

`dart:mirrors` only works on the Dart VM in JIT mode (`dart run`). For apps compiled ahead of time, use `GeneratedReflector` from [`angel3_container_generator`](https://pub.dev/packages/angel3_container_generator), or register everything and use `EmptyReflector`.

## Usage

```dart
import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';

var container = Container(const MirrorsReflector());
```

With Angel3:

```dart
var app = Angel(reflector: const MirrorsReflector());
```

## Migrating from `angel3_container` 9.x

Add `angel3_container_mirrors` to your dependencies, and replace

```dart
import 'package:angel3_container/mirrors.dart';
```

with

```dart
import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';
```
