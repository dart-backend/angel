# Angel3 Sync

[![version](https://img.shields.io/badge/pub-v4.1.1-brightgreen)](https://pub.dev/packages/angel3_sync)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/angel/tree/angel3/packages/sync/LICENSE)

Easily synchronize and scale WebSockets using [belatuk_pub_sub](<https://pub.dev/packages/belatuk_pub_sub>).

## Usage

This package exposes `PubSubSynchronizationChannel`, which can simply be dropped into any `AngelWebSocket` constructor. Once you've set that up, instances of your application will automatically fire events in-sync. That's all you have to do to scale a real-time application with Angel3!

```dart
await app.configure(AngelWebSocket(
    synchronizationChannel: PubSubSynchronizationChannel(
        pub_sub.IsolateClient('<client-id>', adapter.receivePort.sendPort),
    ),
));
```
