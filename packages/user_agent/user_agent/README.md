# Angel3 User Agent

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_user_agent?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/angel/tree/angel3/packages/user_agent/user_agent/LICENSE)

**Replacement of `package:angel_user_agent` with breaking changes to support NNBD.**

Middleware to inject a User Agent object into requests. For convenience's sake, it also exports [`package:user_agent_analyzer`](https://pub.dev/packages/user_agent_analyzer), so `UserAgent` needs no other import.
## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_user_agent: ^10.0.0
```

## Usage

`parseUserAgent` injects the request's `UserAgent` into its container:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_user_agent/angel3_user_agent.dart';

void main() async {
  var app = Angel();

  app.get(
    '/',
    chain([
      parseUserAgent,
      (req, res) {
        var ua = req.container!.make<UserAgent>();
        // Edge and Opera are built on Chromium, but are not Chrome.
        return ua.isChrome || ua.isEdge || ua.isOpera
            ? 'Woohoo! You are running Chrome, Edge or Opera.'
            : 'Sorry, we only support Chrome, Edge and Opera.';
      },
    ]),
  );

  await AngelHttp(app).startServer('127.0.0.1', 3000);
}
```
