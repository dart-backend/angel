library inflection3.singular_verb.test;

import 'package:inflection3/inflection3.dart';
import 'package:test/test.dart';

void main() {
  group('The SingularVerbEncoder', () {
    test('converts verbs from singular to plural', () {
      expect(SINGULARVERB.convert(''), equals(''));
      expect(SINGULARVERB.convert('eat'), equals('eats'));
      expect(SINGULARVERB.convert('go'), equals('goes'));
      expect(SINGULARVERB.convert('box'), equals('boxes'));
      expect(SINGULARVERB.convert('pay'), equals('pays'));
      expect(SINGULARVERB.convert('ride'), equals('rides'));
      expect(SINGULARVERB.convert('write'), equals('writes'));
      expect(SINGULARVERB.convert('wear'), equals('wears'));
      expect(SINGULARVERB.convert('steal'), equals('steals'));
      expect(SINGULARVERB.convert('spring'), equals('springs'));
      expect(SINGULARVERB.convert('speak'), equals('speaks'));
      expect(SINGULARVERB.convert('sing'), equals('sings'));
      expect(SINGULARVERB.convert('bus'), equals('buses'));
      expect(SINGULARVERB.convert('know'), equals('knows'));
      expect(SINGULARVERB.convert('hide'), equals('hides'));
      expect(SINGULARVERB.convert('catch'), equals('catches'));
    });

    test('handles irregular plural verbs', () {
      expect(SINGULARVERB.convert('are'), equals('is'));
      expect(SINGULARVERB.convert('were'), equals('was'));
      expect(SINGULARVERB.convert('have'), equals('has'));
    });
  });
}
