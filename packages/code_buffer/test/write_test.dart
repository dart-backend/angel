import 'package:charcode/charcode.dart';
import 'package:code_buffer/code_buffer.dart';
import 'package:test/test.dart';

main() {
  var buf = new CodeBuffer();
  tearDown(buf.clear);

  test('writeCharCode', () {
    buf.writeCharCode($x);
    expect(buf.toString(), 'x');
  });

  test('write', () {
    buf.write('hello world');
    expect(buf.toString(), 'hello world');
  });

  test('custom space', () {
    var b = new CodeBuffer(space: '+')
      ..writeln('foo')
      ..indent()
      ..writeln('baz');
    expect(b.toString(), 'foo\n+baz');
  });

  test('custom newline', () {
    var b = new CodeBuffer(newline: 'N')
      ..writeln('foo')
      ..indent()
      ..writeln('baz');
    expect(b.toString(), 'fooN  baz');
  });

  test('trailing newline', () {
    var b = new CodeBuffer(trailingNewline: true)..writeln('foo');
    expect(b.toString(), 'foo\n');
  });

  group('multiple lines', () {
    setUp(() {
      buf..writeln('foo')..writeln('bar')..writeln('baz');
      expect(buf.lines, hasLength(3));
      expect(buf.lines[0].text, 'foo');
      expect(buf.lines[1].text, 'bar');
      expect(buf.lines[2].text, 'baz');
    });
  });

  test('indent', () {
    buf
      ..writeln('foo')
      ..indent()
      ..writeln('bar')
      ..indent()
      ..writeln('baz')
      ..outdent()
      ..writeln('quux')
      ..outdent()
      ..writeln('end');
    expect(buf.toString(), 'foo\n  bar\n    baz\n  quux\nend');
  });

  group('sets lastLine text', () {
    test('writeCharCode', () {
      buf.writeCharCode($x);
      expect(buf.lastLine!.text, 'x');
    });

    test('write', () {
      buf.write('hello world');
      expect(buf.lastLine!.text, 'hello world');
    });
  });

  group('sets lastLine lastSpan', () {
    test('writeCharCode', () {
      buf.writeCharCode($x);
      expect(buf.lastLine!.lastSpan!.text, 'x');
    });

    test('write', () {
      buf.write('hello world');
      expect(buf.lastLine!.lastSpan!.text, 'hello world');
    });
  });
}
