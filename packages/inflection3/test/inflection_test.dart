library inflection3.test;

import 'package:test/test.dart';
import 'package:inflection3/inflection3.dart';

void main() {
  group('The inflection library', () {
    test('provides a few convenient helper functions', () {
      expect(pluralize('axis'), equals('axes'));
      expect(convertToPlural('axis'), equals('axes'));
      expect(singularize('Houses'), equals('House'));
      expect(convertToSingular('Houses'), equals('House'));
      expect(convertToSnakeCase('CamelCase'), equals('camel_case'));
      expect(convertToSpinalCase('CamelCase'), equals('camel-case'));
    });
  });
}
