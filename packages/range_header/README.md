# Angel3 Range Header

[![version](https://img.shields.io/badge/pub-v3.0.2-brightgreen)](https://pub.dartlang.org/packages/angel3_range_header)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/range_header/LICENSE)

Range header parser for Angel3. Can be used by any dart backend.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_range_header: ^3.0.0
```

## Usage

```dart
handleRequest(HttpRequest request) async {
  // Parse the header
  var header = RangeHeader.parse(request.headers.value(HttpHeaders.rangeHeader));

  // Optimize/canonicalize it
  var items = RangeHeader.foldItems(header.items);
  header = RangeHeader(items);

  // Get info
  header.items;
  header.rangeUnit;
  print(header.items[0].toContentRange(fileSize));

  // Serve the file
  var transformer = RangeHeaderTransformer(header);
  await file.openRead().transform(transformer).pipe(request.response);
}
```
