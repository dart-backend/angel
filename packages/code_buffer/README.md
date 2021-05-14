# angel3_code_buffer
[![version](https://img.shields.io/badge/pub-v2.12.4-brightgreen)](https://pub.dartlang.org/packages/angel3_code_buffer)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/code_buffer/LICENSE)

An advanced StringBuffer geared toward generating code, and source maps.

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_code_buffer: ^2.0.0
```

# Usage
Use a `CodeBuffer` just like any regular `StringBuffer`:

```dart
String someFunc() {
    var buf = CodeBuffer();
    buf
      ..write('hello ')
      ..writeln('world!');
    return buf.toString();
}
```

However, a `CodeBuffer` supports indentation.

```dart
void someOtherFunc() {
  var buf = CodeBuffer();
  // Custom options...
  var buf = CodeBuffer(newline: '\r\n', space: '\t', trailingNewline: true);
  
  // Any following lines will have an incremented indentation level...
  buf.indent();
  
  // And vice-versa:
  buf.outdent();
}
```

`CodeBuffer` instances keep track of every `SourceSpan` they create.
This makes them useful for codegen tools, or to-JS compilers.

```dart
void someFunc(CodeBuffer buf) {
  buf.write('hello');
  expect(buf.lastLine.text, 'hello');
  
  buf.writeln('world');
  expect(buf.lastLine.lastSpan.start.column, 5);
}
```

You can copy a `CodeBuffer` into another, heeding indentation rules:

```dart
void yetAnotherFunc(CodeBuffer a, CodeBuffer b) {
  b.copyInto(a);
}
```