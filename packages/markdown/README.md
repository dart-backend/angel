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
  angel3_framework: ^10.0.0
  angel3_markdown: ^10.0.0
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

`package:angel3_markdown` by default searches for files with a `.md` extension; however, you can easily override this.

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
    'species': {
      'name': 'sapiens',
      'genus': {'name': 'homo'},
    },
  });
}
```

Objects other than `Map`s and `List`s must have a `toJson()` method that returns a `Map`, as `@serializable` models do; their getters are not read.

To disable interpolation for a single bracket, prefix it with an `@`, ex: `@{{raw | not_interpolated | angular}}`.

Interpolated values are put into the rendered HTML, HTML-escaped, so they appear as given in text (including code and tables) and in quoted HTML attributes, and HTML such as `<script>` or Markdown such as `[link](...)` in them is not rendered. In the URL of a Markdown link they are also percent-encoded: a value that starts the URL, as in `[x]({{url}})`, as a whole URL, and a value after other text of the URL, as in `[x](/search?q={{q}})` or `[x](/users/{{id}})`, as a component, so that its `/`, `?`, `&`, `=` and `#` are encoded too. The ids of headings are generated as for the Markdown with the values. For values you trust and want rendered as Markdown, pass `escape: false` to `markdown()`.

Escaping has these limits:

* Values are not escaped for JavaScript or CSS. Do not put them into `<script>` or `<style>` elements, or into event handler attributes such as `onclick`.
* The URL of a Markdown link or image with values, as in `[x]({{url}})` or `[x]({{proto}}:{{rest}})`, is replaced with `#` when its scheme is not `http`, `https` or `mailto`, so `javascript:` and `data:` URLs do not get through, and when it starts with a value and `//`, which would link to a host the value chooses. A host in the view itself, as in `[x](//cdn.example/{{file}})`, is kept. URLs in HTML attributes, as in `<a href="{{url}}">`, are not checked.
* Markdown does not see the content of a value, so a value cannot form Markdown syntax with the text around it. `<{{url}}>` and a bare `{{url}}` do not become links; write `[{{url}}]({{url}})` instead.

Each part of an expression after the first is read as a key of a `Map`, an index of a `List` (`{{items.0}}`), one of the getters `length`, `isEmpty` and `isNotEmpty` (of a `String`, `Iterable` or `Map`) or `first` and `last` (of an `Iterable`, such as a `List` or `Set`), or else a key of what the object's `toJson()` returns.

View names are resolved inside the views directory. A name that points outside it, such as `../secret`, also through a symbolic link, or a view that does not exist, throws a 404 `AngelHttpException`.

## Migrating from 9.x

Version 10.0.0 changes how views are rendered, which can change the output of existing views without an error:

* Interpolated values are escaped. Views that put HTML or Markdown into the page through locals render it as text; pass `escape: false` for trusted values.
* `<{{url}}>` and a bare `{{url}}` no longer become links; write `[{{url}}]({{url}})`.
* Expressions no longer read getters through `dart:mirrors`. Pass `Map`s, or objects whose `toJson()` returns one. Use the JSON keys, which can differ from the Dart names (e.g. `full_name` for `fullName`), and add computed getters to `toJson()` or to the locals.
* The URL of a Markdown link or image with values renders as `#` when its scheme is not `http`, `https` or `mailto`, or when it starts with a value and `//`.
* A view that does not exist throws a 404 `AngelHttpException` instead of a `FileSystemException`.

## Templates

Markdown is frequently used to build the *content* of sites, but not the templates.
You might want to wrap the content of pages in a custom template to apply pretty
CSS and JS, etc:

```dart
import 'dart:convert';

configureServer(Angel app) async {
  await app.configure(
    markdown(
        // The directory where your views are located.
        fs.directory('views'), template: (content, Map locals) {
      return '''<!DOCTYPE html>
<html>
    <head>
        <title>${htmlEscape.convert('${locals['title']}')} - My Site</title>
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

The `template` callback receives the raw `locals`, which are not escaped as interpolated values are: escape them yourself, e.g. with `htmlEscape` from `dart:convert`.

The `template` function will have access to whatever values were passed to the renderer, or an empty `Map`.

## Enhancing Markdown

You can pass an `extensionSet` to add additional features to the Markdown renderer. By default, this plug-in configures it to enable Github-flavored Markdown.
