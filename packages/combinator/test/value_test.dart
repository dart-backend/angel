import 'package:angel3_combinator/angel3_combinator.dart';
import 'package:test/test.dart';
import 'common.dart';

void main() {
  var parser = match('hello').value((r) => 'world');

  test('sets value', () {
    expect(parser.parse(scan('hello world')).value, 'world');
  });

  test('no value if no match', () {
    expect(parser.parse(scan('goodbye world')).value, isNull);
  });
}
