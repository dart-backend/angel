# File Service for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_file_service?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/file_service/LICENSE)

Angel service that persists data to a file on disk, stored as a JSON list. It uses a simple mutex to prevent race conditions, and caches contents in memory until changes are made.

The file will be created on read/write, if it does not already exist.

This package is useful in development, as it prevents you from having to install an external database to run your server.

When running a multi-threaded server, there is no guarantee that file operations will be mutually excluded. Thus, try to only use this one a single-threaded server if possible, or one with very low load.

While not necessarily *slow*, this package makes no promises about performance.

## Usage

```dart
configureServer(Angel app) async {
  // Just like a normal service
  app.use(
    '/api/todos',
    JsonFileService(
      const LocalFileSystem().file('todos_db.json')
    ),
  );
}
```
