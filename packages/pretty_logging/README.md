# pretty\_logging
[![version](https://img.shields.io/badge/pub-v2.12.4-brightgreen)](https://pub.dartlang.org/packages/angel3_pretty_logging)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/pretty_logging/LICENSE)

Standalone helper for colorful logging output, using pkg:io AnsiCode.

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_pretty_logging: ^3.0.0
```

# Usage
Basic usage is very simple:

```dart
myLogger.onRecord.listen(prettyLog);
```

However, you can conditionally pass logic to omit printing an
error, provide colors, or to provide a custom print function:

```dart
var pretty = prettyLog(
  logColorChooser: (_) => red,
  printFunction: stderr.writeln,
  omitError: (r) {
    var err = r.error;
    return err is AngelHttpException && err.statusCode != 500;
  },
);
myLogger.onRecord.listen(pretty);
```
