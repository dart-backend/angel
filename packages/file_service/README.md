# File Service for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_file_service?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/file_service/LICENSE)

Angel service that persists data to a file on disk, stored as a JSON list. It uses a simple mutex to prevent race conditions, and caches contents in memory until changes are made.

The file will be created on read/write, if it does not already exist.

This package is useful in development, as it prevents you from having to install an external database to run your server.

One service reads and writes its file one call at a time, so that no change is lost. Several services of the same file, such as one in each isolate of a multi-threaded server, are not excluded from each other, so use one service per file, in a single isolate, if possible.

The file is read again when its modification time or its size changes, so that most edits made outside of the service are picked up. One that keeps the size, within the resolution of the file system's times, can be missed, and overwritten by the next write.

A save writes a whole copy of the data to `<file>.tmp`, next to the file, before it writes the file in place, so that a save cut off, as by a full disk, is restored from the copy by the next call. The copy is made with the process's default permissions, so keep the file in a directory that only the server can read if its data is private.

Values are kept as JSON has them: a `DateTime` is stored, and returned, as its ISO 8601 string. To work with typed values, such as dates, convert them where the meaning of a field is known, e.g. with a `TypedService` or a model's `fromMap`.

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
