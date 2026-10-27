# Mustache View Template for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_mustache?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/mustache/LICENSE)

A service that renders Mustache template into HTML view for [Angel3](https://angel3-framework.web.app/) framework.

Thanks so much @c4wrd for his help with bringing this project to life!

## Installation

In `pubspec.yaml`:

```yaml
dependencies:
    angel3_mustache: ^10.0.0
```

## Usage

```dart
const FileSystem fs = LocalFileSystem();

configureServer(Angel app) async {
  // Run the plug-in
  await app.configure(mustache(fs.directory('views')));

  // Render `hello.mustache`
  app.get('/hello', (req, res) => res.render('hello', {'name': 'world'}));
}
```

## Options

- **partialsPath**: A path within the viewsDirectory to search for partials in.
    Default is `./partials`.
- **fileExtension**: The file extension to search for. Default is `.mustache`.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Views**: a view name that resolves outside the views directory (`../secret`, an absolute path, a symbolic link out of it), and a missing view, throw a 404 `AngelHttpException`, instead of reading the file or throwing a `FileSystemException`.
* **Partials**: a partial that resolves outside the partials directory, or does not exist, renders as nothing, as Mustache specifies.
