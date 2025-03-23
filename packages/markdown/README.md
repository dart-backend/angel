# Angel3 Markdown

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_markdown?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/markdown/LICENSE)

Markdown view generator for Angel3.

With this plug-in, you can easily serve static sites without doing more than writing simple Markdown. Thus, it is a friendly choice for writing API documentation or other tedious HTML-writing tasks.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^8.0.0
  angel3_markdown: ^8.0.0
```

## Usage

It's very straightforward to configure an Angel server to use Markdown. Keep in mind to use `package:file` instead of `dart:io`:

```dart
configureServer(Angel app) async {
  var fs = LocalFileSystem();
  await app.configure(markdown(
    // The directory where your views are located.
    fs.directory('views'),
  ));
}
```

You can then generate HTML on-the-fly in a request handler. Assuming your view directory contained a file named `hello.md`, the following would render it as an HTML response:

```dart
configureServer(Angel app) async {
  app.get('/hello', (res) => res.render('hello'));
}
```

`package:angel3_markdown` by default searches for files with a `.md` extension; however,
you can easily override this.

## Interpolation

`angel3_markdown` can interpolate the values of data from `locals` before building the Markdown. For example, with the following template `species.md`:

```markdown
# Species: {{species.name}}
The species *{{species.genus.name}} {{species.name}}* is fascinating...
```

You can render as follows:

```dart
requestHandler(ResponseContext res) {
  return res.render('species', {
    'species': new Species('sapiens', genius: 'homo')
  });
}
```

To disable interpolation for a single bracket, prefix it with an `@`, ex: `@{{raw | not_interpolated | angular}}`.

## Templates

Markdown is frequently used to build the *content* of sites, but not the templates.
You might want to wrap the content of pages in a custom template to apply pretty
CSS and JS, etc:

```dart
configureServer(Angel app) async {
  await app.configure(
    markdown(
        // The directory where your views are located.
        fs.directory('views'), template: (content, Map locals) {
      return '''<!DOCTYPE html>
<html>
    <head>
        <title>${locals['title']} - My Site</title>
    </head>
    <body>
      $content
    </body>
</html>
        ''';
    }),
  );
}
```

The `template` function will have access to whatever values were passed to the renderer, or an empty `Map`.

## Enhancing Markdown

You can pass an `extensionSet` to add additional features to the Markdown renderer. By default, this plug-in configures it to enable Github-flavored Markdown.
