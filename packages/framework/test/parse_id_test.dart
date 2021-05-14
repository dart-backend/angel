import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

void main() {
  test('null', () {
    //expect(Service.parseId('null'), null);
    //expect(Service.parseId(null), null);

    expect(() => Service.parseId('null'), throwsArgumentError);
    expect(() => Service.parseId(null), throwsArgumentError);
  });

  test('String', () {
    expect(Service.parseId('23'), '23');
  });

  test('int', () {
    expect(Service.parseId<int>('23'), 23);
  });

  test('double', () {
    expect(Service.parseId<double>('23.4'), 23.4);
  });

  test('num', () {
    expect(Service.parseId<num>('23.4'), 23.4);
  });

  test('bool', () {
    expect(Service.parseId<bool>('true'), true);
    expect(Service.parseId<bool>(true), true);
    expect(Service.parseId<bool>('false'), false);
    expect(Service.parseId<bool>(false), false);
    expect(Service.parseId<bool>('hmm'), false);
  });
}
