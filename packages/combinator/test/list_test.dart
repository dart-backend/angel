import 'package:combinator/combinator.dart';
import 'package:test/test.dart';
import 'common.dart';

main() {
  var number = chain([
    match(RegExp(r'[0-9]+')).value((r) => int.parse(r.span!.text)),
    match(',').opt(),
  ]).first().cast<int>();

  var numbers = number.plus();

  test('sort', () {
    var parser = numbers.sort((a, b) => a!.compareTo(b!));
    expect(parser.parse(scan('21,2,3,34,20')).value, [2, 3, 20, 21, 34]);
  });
  test('reduce', () {
    var parser = numbers.reduce((a, b) => a! + b!);
    expect(parser.parse(scan('21,2,3,34,20')).value, 80);
    expect(parser.parse(scan('not numbers')).value, isNull);
  });
}
