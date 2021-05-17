library inflection3.spinal_case.test;

import 'package:inflection3/inflection3.dart';
import 'package:test/test.dart';

void main() {
  group('The SpinalCaseEncoder', () {
    test('converts phrases to "spinal-case"', () {
      expect(SPINAL_CASE.convert(''), equals(''));
      expect(SPINAL_CASE.convert('CamelCaseName'), equals('camel-case-name'));
      expect(SPINAL_CASE.convert('propertyName'), equals('property-name'));
      expect(SPINAL_CASE.convert('property'), equals('property'));
      expect(SPINAL_CASE.convert('snake_case'), equals('snake-case'));
      expect(SPINAL_CASE.convert('This is a nice article'),
          equals('this-is-a-nice-article'));
    });
  });
}
