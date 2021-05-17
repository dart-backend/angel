library inflection3.is_tense.test;

import 'package:test/test.dart';

import '../lib/inflection3.dart';

void main() {
  group("isTense", () {
    test('correctly identifies if a word is in past tense', () {
      expect(isPastTense('run'), false);
      expect(isPastTense('ran'), true);
      expect(isPastTense('PusHed'), true);
      expect(isPastTense('PusH'), false);
    });
  });
}
