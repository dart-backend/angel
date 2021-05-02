library inflection.plural_verb.test;

import 'package:test/test.dart';

import '../lib/src/plural_verb.dart';

void main() {
  group("The PluralVerbEncoder", () {
    test("converts verbs from singular to plural", () {
      expect(PLURALVERB.convert(""), equals(""));
      expect(PLURALVERB.convert("eats"), equals("eat"));
      expect(PLURALVERB.convert("goes"), equals("go"));
      expect(PLURALVERB.convert("boxes"), equals("box"));
      expect(PLURALVERB.convert("pays"), equals("pay"));
      expect(PLURALVERB.convert("rides"), equals("ride"));
      expect(PLURALVERB.convert("writes"), equals("write"));
      expect(PLURALVERB.convert("wears"), equals("wear"));
      expect(PLURALVERB.convert("steals"), equals("steal"));
      expect(PLURALVERB.convert("springs"), equals("spring"));
      expect(PLURALVERB.convert("speaks"), equals("speak"));
      expect(PLURALVERB.convert("sings"), equals("sing"));
      expect(PLURALVERB.convert("buses"), equals("bus"));
      expect(PLURALVERB.convert("knows"), equals("know"));
      expect(PLURALVERB.convert("hides"), equals("hide"));
      expect(PLURALVERB.convert("catches"), equals("catch"));
    });

    test("handles irregular plural verbs", () {
      expect(PLURALVERB.convert("am"), equals("are"));
      expect(PLURALVERB.convert("is"), equals("are"));
      expect(PLURALVERB.convert("was"), equals("were"));
      expect(PLURALVERB.convert("has"), equals("have"));
    });
  });
}
