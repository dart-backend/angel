library inflection3.plural.test;

import 'package:inflection3/inflection3.dart';
import 'package:inflection3/src/uncountable_nouns.dart';
import 'package:test/test.dart';

void main() {
  group('The PluralEncoder', () {
    test('converts nouns from singular to plural', () {
      expect(PLURAL.convert(''), equals(''));
      expect(PLURAL.convert('House'), equals('Houses'));
      expect(PLURAL.convert('house'), equals('houses'));
      expect(PLURAL.convert('dog'), equals('dogs'));
      expect(PLURAL.convert('axis'), equals('axes'));
      expect(PLURAL.convert('testis'), equals('testes'));
      expect(PLURAL.convert('octopus'), equals('octopi'));
      expect(PLURAL.convert('virus'), equals('viri'));
      expect(PLURAL.convert('octopi'), equals('octopi'));
      expect(PLURAL.convert('viri'), equals('viri'));
      expect(PLURAL.convert('alias'), equals('aliases'));
      expect(PLURAL.convert('status'), equals('statuses'));
      expect(PLURAL.convert('bus'), equals('buses'));
      expect(PLURAL.convert('buffalo'), equals('buffaloes'));
      expect(PLURAL.convert('tomato'), equals('tomatoes'));
      expect(PLURAL.convert('ultimatum'), equals('ultimata'));
      expect(PLURAL.convert('pentium'), equals('pentia'));
      expect(PLURAL.convert('ultimata'), equals('ultimata'));
      expect(PLURAL.convert('pentia'), equals('pentia'));
      expect(PLURAL.convert('nemesis'), equals('nemeses'));
      expect(PLURAL.convert('hive'), equals('hives'));
      expect(PLURAL.convert('fly'), equals('flies'));
      expect(PLURAL.convert('dish'), equals('dishes'));
      expect(PLURAL.convert('bench'), equals('benches'));
      expect(PLURAL.convert('matrix'), equals('matrices'));
      expect(PLURAL.convert('vertex'), equals('vertices'));
      expect(PLURAL.convert('index'), equals('indices'));
      expect(PLURAL.convert('mouse'), equals('mice'));
      expect(PLURAL.convert('louse'), equals('lice'));
      expect(PLURAL.convert('mice'), equals('mice'));
      expect(PLURAL.convert('lice'), equals('lice'));
      expect(PLURAL.convert('ox'), equals('oxen'));
      expect(PLURAL.convert('ox'), equals('oxen'));
      expect(PLURAL.convert('oxen'), equals('oxen'));
      expect(PLURAL.convert('quiz'), equals('quizzes'));
    });

    test('handles uncountable nouns', () {
      uncountableNouns.forEach((noun) {
        expect(PLURAL.convert(noun), equals(noun));
      });

      uncountableNouns.forEach((noun) {
        final upperNoun = noun.toUpperCase();
        expect(PLURAL.convert(upperNoun), equals(upperNoun));
      });
    });

    test('handles irregular plural nouns', () {
      expect(PLURAL.convert('person'), equals('people'));
      expect(PLURAL.convert('Child'), equals('Children'));
      expect(PLURAL.convert('children'), equals('children'));
      expect(PLURAL.convert('man'), equals('men'));
    });
  });
}
