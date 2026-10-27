# JAEL3 Web

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/jael3_web?include_prereleases)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/jael/jael_web/LICENSE)

Experimental virtual DOM/SPA engine built on Jael. Supports SSR.
**Not ready for production use.**

## Installation

This package is not published on pub.dev. Depend on it from the repository, adding a `ref:` for a branch or a tag:

```yaml
dependencies:
  jael3_web:
    git:
      url: https://github.com/dart-backend/angel.git
      path: packages/jael/jael_web
```

## Usage

A component renders a Jael template, or builds its DOM in Dart:

```dart
import 'package:jael3_web/jael3_web.dart';
import 'package:jael3_web/elements.dart';

part 'main.g.dart';

@Jael(
  template: '''
<div>
  <h1>Hello, Jael!</h1>
  <i>Current time: {{now}}</i>
</div>
''',
)
class Hello extends Component with _HelloJaelTemplate {
  @override
  DateTime get now => DateTime.now();
}

// Could also have been:
class Hello2 extends Component {
  DateTime get now => DateTime.now();

  @override
  DomNode render() {
    return div(
      c: [
        h1(c: [text('Hello, Jael!')]),
        i(c: [text('Current time: $now')]),
      ],
    );
  }
}
```

## TODO

* Bug: Builder failed to generate the class
