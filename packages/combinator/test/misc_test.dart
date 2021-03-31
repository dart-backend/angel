import 'package:combinator/combinator.dart';
import 'package:matcher/matcher.dart';
import 'package:test/test.dart';
import 'common.dart';

main() {
  test('advance', () {
    var scanner = scan('hello world');

    // Casted -> dynamic just for the sake of coverage.
    var parser = match('he').forward(2).castDynamic();
    parser.parse(scanner);
    expect(scanner.position, 4);
  });

  test('change', () {
    var parser = match('hello').change((r) => r.change(value: 23));
    expect(parser.parse(scan('helloworld')).value, 23);
  });

  test('check', () {
    var parser = match<int>(new RegExp(r'[A-Za-z]+'))
        .value((r) => r.span!.length)
        .check(greaterThan(3));
    expect(parser.parse(scan('helloworld')).successful, isTrue);
    expect(parser.parse(scan('yo')).successful, isFalse);
  });

  test('map', () {
    var parser =
        match(new RegExp(r'[A-Za-z]+')).map<int>((r) => r.span!.length);
    expect(parser.parse(scan('hello')).value, 5);
  });

  test('negate', () {
    var parser = match('hello').negate(errorMessage: 'world');
    expect(parser.parse(scan('goodbye world')).successful, isTrue);
    expect(parser.parse(scan('hello world')).successful, isFalse);
    expect(parser.parse(scan('hello world')).errors.first.message, 'world');
  });

  group('opt', () {
    var single = match('hello').opt(backtrack: true);
    var list = match('hel').then(match('lo')).opt();

    test('succeeds if present', () {
      expect(single.parse(scan('hello')).successful, isTrue);
      expect(list.parse(scan('hello')).successful, isTrue);
    });

    test('succeeds if not present', () {
      expect(single.parse(scan('goodbye')).successful, isTrue);
      expect(list.parse(scan('goodbye')).successful, isTrue);
    });

    test('backtracks if not present', () {
      for (var parser in [single, list]) {
        var scanner = scan('goodbye');
        var pos = scanner.position;
        parser.parse(scanner);
        expect(scanner.position, pos);
      }
    });
  });

  test('safe', () {});
}
