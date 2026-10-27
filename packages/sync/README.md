# Angel3 Sync

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_sync?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/angel/tree/angel3/packages/sync/LICENSE)

Easily synchronize and scale WebSockets using [belatuk_pub_sub](<https://pub.dev/packages/belatuk_pub_sub>).

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_sync: ^10.0.0
```

## Usage

This package exposes `PubSubSynchronizationChannel`, which can simply be dropped into any `AngelWebSocket` constructor. Once you've set that up, instances of your application will automatically fire events in-sync. That's all you have to do to scale a real-time application with Angel3!

```dart
var ws = AngelWebSocket(
  app,
  synchronizationChannel: PubSubSynchronizationChannel(
    pub_sub.IsolateClient('<client-id>', adapter.receivePort.sendPort),
  ),
);
await app.configure(ws.configureServer);
app.get('/ws', ws.handleRequest);
```

The channel is closed, with its `pub_sub` client, when the app is.
