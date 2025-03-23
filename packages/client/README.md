# Angel3 Client

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_client?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/client/LICENSE)

A browser, mobile and command line based client that supports querying Angel3 backend.

## Usage

```dart
// Choose one or the other, depending on platform
import 'package:angel3_client/io.dart';
import 'package:angel3_client/browser.dart';
import 'package:angel3_client/flutter.dart';

main() async {
  Angel app = Rest("http://localhost:3000");
}
```

You can call `service` to receive an instance of `Service`, which acts as a client to a service on the server at the given path (say that five times fast!).

```dart
foo() async {
  Service Todos = app.service("todos");
  List<Map> todos = await Todos.index();

  print(todos.length);
}
```

The CLI client also supports reflection via `package:belatuk_json_serializer`. There is no need to work with Maps; you can use the same class on the client and the server.

```dart
class Todo extends Model {
  String text;

  Todo({String this.text});
}

bar() async {
  // By the next release, this will just be:
  // app.service<Todo>("todos")
  Service Todos = app.service("todos", type: Todo);
  List<Todo> todos = await Todos.index();

  print(todos.length);
}
```

Just like on the server, services support `index`, `read`, `create`, `modify`, `update` and `remove`.

## Authentication

Local auth:

```dart
var auth = await app.authenticate(type: 'local', credentials: {username: ..., password: ...});
print(auth.token);
print(auth.data); // User object
```

Revive an existing jwt:

```dart
Future<AngelAuthResult> reviveJwt(String jwt) {
  return app.authenticate(credentials: {'token': jwt});
}
```

Via Popup:

```dart
app.authenticateViaPopup('/auth/google').listen((jwt) {
  // Do something with the JWT
});
```

Resume a session from localStorage (browser only):

```dart
// Automatically checks for JSON-encoded 'token' in localStorage,
// and tries to revive it
await app.authenticate();
```

Logout:

```dart
await app.logout();
```

## Live Updates

Oftentimes, you will want to update a collection based on updates from a service. Use `ServiceList` for this case:

```dart
build(BuildContext context) async {
  var list = ServiceList(app.service('api/todos'));
  
  return StreamBuilder(
    stream: list.onChange,
    builder: _yourBuildFunction,
  );
}
```
