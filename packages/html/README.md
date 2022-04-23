# Angel3 HTML

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_html?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/html/LICENSE)

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
  angel3_html: ^6.0.0
```

## Usage

The `renderHtml` function does all the magic for you.

```dart
configureServer(Angel app) async {
  // Wire it up!
  app.fallback(renderHtml());
  
  // You can pass a custom StringRenderer if you need more control over the output.
  app.fallback(renderHtml(renderer: new StringRenderer(html5: false)));
  
  app.get('/greet/:name', (RequestContext req) {
    return html(lang: 'en', c: [
     head(c: [
       meta(name: 'viewport', content: 'width=device-width, initial-scale=1'),
       title(c: [
         text('Greetings!')
       ]),
     ]),
     body(c: [
       h1(c: [
         text('Hello, ${req.params['id']}!'),
       ]),
     ]),
   ]);
  });
}
```

By default, `renderHtml` will ignore the client's `Accept` header. However, if you pass `enforceAcceptHeader` as `true`, then a `406 Not Acceptable` error will be thrown if the client doesn't accept `*/*` or `text/html`.

```dart
configureServer(Angel app) async {
  // Wire it up!
  app.fallback(renderHtml(enforceAcceptHeader: true));
  
  // ...
}
```
