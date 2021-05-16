library inflection.snake_case.test;

import 'package:test/test.dart';

import '../lib/src/snake_case.dart';

void main() {
  group("The SnakeCaseEncoder", () {
    test("converts phrases to 'snake_case'", () {
      expect(SNAKE_CASE.convert(''), equals(''));
      expect(SNAKE_CASE.convert("CamelCaseName"), equals("camel_case_name"));
      expect(SNAKE_CASE.convert("propertyName"), equals("property_name"));
      expect(SNAKE_CASE.convert("property"), equals("property"));
      expect(SNAKE_CASE.convert("lisp-case"), equals("lisp_case"));
      expect(SNAKE_CASE.convert("This is a nice article"),
          equals("this_is_a_nice_article"));
    });
  });
}
