# Angel3 Http Exception

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_http_exception?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/http_exception/LICENSE)

Exception class that can be serialized to JSON and serialized to clients. Angel3's HTTP exception class.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_http_exception: ^10.0.0
```

## Usage

Throw an `AngelHttpException` from a handler, and Angel3 sends its status and message to the client:

```dart
import 'package:angel3_http_exception/angel3_http_exception.dart';

void main() {
  try {
    throw AngelHttpException.notFound(message: "Can't find that page!");
  } on AngelHttpException catch (e) {
    print(e.statusCode); // 404
    print(e.toJson()); // The JSON sent to the client
  }

  // An error of a response, as a client reads it:
  var e = AngelHttpException.fromMap({'status_code': 400, 'message': 'Bad'});
  print(e.statusCode); // 400
}
```
