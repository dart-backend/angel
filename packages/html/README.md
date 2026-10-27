# Angel3 HTML

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_html?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/html/LICENSE)

A plug-in that allows you to return `belatuk_html_builder` AST's from request handlers, and have them sent as HTML automatically.

[`package:belatuk_html_builder`](https://pub.dev/packages/belatuk_html_builder) is a simple virtual DOM library with a handy Dart DSL that makes it easy to build HTML AST's:

```dart
import 'package:belatuk_html_builder/elements.dart';

Node myDom = html(lang: 'en', c: [
  head(c: [
    meta(name: 'viewport', content: 'width=device-width, initial-scale=1'),
    title(c: [
      text('html_builder example page')
    ]),
  ]),
  body(c: [
    h1(c: [
      text('Hello world!'),
    ]),
  ]),
]);
```

This plug-in means that you can now `return` these AST's, and Angel will automatically send them to clients. Ultimately, the implication is that you can use `belatuk_html_builder` as a substitute for a templating system within Dart. With [hot reloading](https://pub.dev/packages/angel3_hot), you won't even need to reload your server (as it should be).

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_html: ^10.0.0
```

## Usage

The `renderHtml` function does all the magic for you.

```dart
configureServer(Angel app) async {
  // Wire it up!
  app.fallback(renderHtml());
  
  // You can pass a custom StringRenderer if you need more control over the output.
  app.fallback(renderHtml(renderer: StringRenderer(html5: false)));
  
  app.get('/greet/:name', (req, res) {
    return html(lang: 'en', c: [
     head(c: [
       meta(name: 'viewport', content: 'width=device-width, initial-scale=1'),
       title(c: [
         text('Greetings!')
       ]),
     ]),
     body(c: [
       h1(c: [
         text('Hello, ${req.params['name']}!'),
       ]),
     ]),
   ]);
  });
}
```

By default, `renderHtml` will ignore the client's `Accept` header. However, if you pass `enforceAcceptHeader` as `true`, then a `406 Not Acceptable` error will be thrown if the client doesn't accept `*/*` or `text/html`. A request without an `Accept` header accepts any type.

```dart
configureServer(Angel app) async {
  // Wire it up!
  app.fallback(renderHtml(enforceAcceptHeader: true));
  
  // ...
}
```

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Charset**: pages are sent as `text/html; charset=utf-8`, where they had no charset.
* **`enforceAcceptHeader`** is a `bool` that defaults to `false`, not a `bool?`: pass `true` or `false`, not `null`.
