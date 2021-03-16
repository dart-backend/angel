import 'package:code_buffer/code_buffer.dart';
import 'package:test/test.dart';

main() {
  var a = new CodeBuffer(), b = new CodeBuffer();

  setUp(() {
    a.writeln('outer block 1');
    b..writeln('inner block 1')..writeln('inner block 2');
    b.copyInto(a..indent());
    a
      ..outdent()
      ..writeln('outer block 2');
  });

  tearDown(() {
    a.clear();
    b.clear();
  });

  test('sets correct text', () {
    expect(
        a.toString(),
        [
          'outer block 1',
          '  inner block 1',
          '  inner block 2',
          'outer block 2',
        ].join('\n'));
  });

  test('sets lastLine+lastSpan', () {
    var c = new CodeBuffer()
      ..indent()
      ..write('>')
      ..writeln('innermost');
    c.copyInto(a);
    expect(a.lastLine!.text, '>innermost');
    expect(a.lastLine!.span.start.column, 2);
    expect(a.lastLine!.lastSpan!.start.line, 4);
    expect(a.lastLine!.lastSpan!.start.column, 3);
    expect(a.lastLine!.lastSpan!.end.line, 4);
    expect(a.lastLine!.lastSpan!.end.column, 12);
  });
}
