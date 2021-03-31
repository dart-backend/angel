import 'package:combinator/combinator.dart';
import 'package:test/test.dart';
import 'common.dart';

main() {
  test('match string', () {
    expect(match('hello').parse(scan('hello world')).successful, isTrue);
  });
  test('match start only', () {
    expect(match('hello').parse(scan('goodbye hello')).successful, isFalse);
  });

  test('fail if no match', () {
    expect(match('hello').parse(scan('world')).successful, isFalse);
  });
}
