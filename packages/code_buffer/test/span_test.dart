import 'package:charcode/charcode.dart';
import 'package:angel3_code_buffer/angel3_code_buffer.dart';
import 'package:test/test.dart';

void main() {
  var buf = CodeBuffer();
  tearDown(buf.clear);

  test('writeCharCode', () {
    buf.writeCharCode($x);
    expect(buf.lastLine!.lastSpan!.start.column, 0);
    expect(buf.lastLine!.lastSpan!.start.line, 0);
    expect(buf.lastLine!.lastSpan!.end.column, 1);
    expect(buf.lastLine!.lastSpan!.end.line, 0);
  });

  test('write', () {
    buf.write('foo');
    expect(buf.lastLine!.lastSpan!.start.column, 0);
    expect(buf.lastLine!.lastSpan!.start.line, 0);
    expect(buf.lastLine!.lastSpan!.end.column, 3);
    expect(buf.lastLine!.lastSpan!.end.line, 0);
  });

  test('multiple writes in one line', () {
    buf..write('foo')..write('baz');
    expect(buf.lastLine!.lastSpan!.start.column, 3);
    expect(buf.lastLine!.lastSpan!.start.line, 0);
    expect(buf.lastLine!.lastSpan!.end.column, 6);
    expect(buf.lastLine!.lastSpan!.end.line, 0);
  });

  test('multiple lines', () {
    buf
      ..writeln('foo')
      ..write('bar')
      ..write('+')
      ..writeln('baz');
    expect(buf.lastLine!.lastSpan!.start.column, 4);
    expect(buf.lastLine!.lastSpan!.start.line, 1);
    expect(buf.lastLine!.lastSpan!.end.column, 7);
    expect(buf.lastLine!.lastSpan!.end.line, 1);
  });
}
