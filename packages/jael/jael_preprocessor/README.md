# Jael Ppreprocessor

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/jael3_preprocessor?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/jael/jael_preprocessor/LICENSE)

A pre-processor for resolving blocks and includes within [Jael 3](https://pub.dev/packages/jael3) templates.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  jael3_prepreprocessor: ^8.0.0
```

## Usage

It is unlikely that you will directly use this package, as it is more of an implementation detail than a requirement. However, it is responsible for handling `include` and `block` directives (template inheritance), so you are a package maintainer and want to support Jael, read on.

To keep things simple, just use the `resolve` function, which will take care of inheritance for you.

```dart
import 'package:jael3_preprocessor/jael3_preprocessor.dart' as jael;

myFunction() async {
  var doc = await parseTemplateSomehow();
  var resolved = await jael.resolve(doc, dir, onError: (e) => doSomething());
}
```

You may occasionally need to manually patch in functionality that is not available through the official Jael packages. To achieve this, simply provide an `Iterable` of `Patcher` functions:

```dart
myOtherFunction(jael.Document doc) {
  return jael.resolve(doc, dir, onError: errorHandler, patch: [
    syntactic(),
    sugar(),
    etc(),
  ]);
}
```

**This package uses `package:file`, rather than `dart:io`.**
