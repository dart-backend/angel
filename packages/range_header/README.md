# range_header

[![Pub](https://img.shields.io/pub/v/range_header.svg)](https://pub.dartlang.org/packages/range_header)
[![build status](https://travis-ci.org/thosakwe/range_header.svg)](https://travis-ci.org/thosakwe/range_header)

Range header parser for Dart.

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  range_header: ^2.0.0
```

# Usage

```dart
handleRequest(HttpRequest request) async {
  // Parse the header
  var header = new RangeHeader.parse(request.headers.value(HttpHeaders.rangeHeader));

  // Optimize/canonicalize it
  var items = RangeHeader.foldItems(header.items);
  header = new RangeHeader(items);

  // Get info
  header.items;
  header.rangeUnit;
  print(header.items[0].toContentRange(fileSize));

  // Serve the file
  var transformer = new RangeHeaderTransformer(header);
  await file.openRead().transform(transformer).pipe(request.response);
}
```
