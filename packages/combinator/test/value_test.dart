import 'package:combinator/combinator.dart';
import 'package:test/test.dart';
import 'common.dart';

main() {
  var parser = match('hello').value((r) => 'world');

  test('sets value', () {
    expect(parser.parse(scan('hello world'))!.value, 'world');
  });

  test('no value if no match', () {
    expect(parser.parse(scan('goodbye world'))!.value, isNull);
  });
}
