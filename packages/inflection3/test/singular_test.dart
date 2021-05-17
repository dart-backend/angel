library inflection3.singular.test;

import 'package:test/test.dart';

import '../lib/src/singular.dart';
import '../lib/src/uncountable_nouns.dart';

void main() {
  group("The SingularEncoder", () {
    test("converts nouns from plural to singular", () {
      expect(SINGULAR.convert(""), equals(""));
      expect(SINGULAR.convert("Houses"), equals("House"));
      expect(SINGULAR.convert("houses"), equals("house"));
      expect(SINGULAR.convert("ultimata"), equals("ultimatum"));
      expect(SINGULAR.convert("pentia"), equals("pentium"));
      expect(SINGULAR.convert("analyses"), equals("analysis"));
      expect(SINGULAR.convert("diagnoses"), equals("diagnosis"));
      expect(SINGULAR.convert("Parentheses"), equals("Parenthesis"));
      expect(SINGULAR.convert("lives"), equals("life"));
      expect(SINGULAR.convert("hives"), equals("hive"));
      expect(SINGULAR.convert("tives"), equals("tive"));
      expect(SINGULAR.convert("shelves"), equals("shelf"));
      expect(SINGULAR.convert("qualities"), equals("quality"));
      expect(SINGULAR.convert("series"), equals("series"));
      expect(SINGULAR.convert("movies"), equals("movie"));
      expect(SINGULAR.convert("benches"), equals("bench"));
      expect(SINGULAR.convert("fishes"), equals("fish"));
      expect(SINGULAR.convert("mice"), equals("mouse"));
      expect(SINGULAR.convert("lice"), equals("louse"));
      expect(SINGULAR.convert("buses"), equals("bus"));
      expect(SINGULAR.convert("shoes"), equals("shoe"));
      expect(SINGULAR.convert("testis"), equals("testis"));
      expect(SINGULAR.convert("crisis"), equals("crisis"));
      expect(SINGULAR.convert("axes"), equals("axis"));
      expect(SINGULAR.convert("axis"), equals("axis"));
      expect(SINGULAR.convert("viri"), equals("virus"));
      expect(SINGULAR.convert("octopi"), equals("octopus"));
      expect(SINGULAR.convert("aliases"), equals("alias"));
      expect(SINGULAR.convert("statuses"), equals("status"));
      expect(SINGULAR.convert("vertices"), equals("vertex"));
      expect(SINGULAR.convert("indices"), equals("index"));
      expect(SINGULAR.convert("Matrices"), equals("Matrix"));
      expect(SINGULAR.convert("quizzes"), equals("quiz"));
      expect(SINGULAR.convert("databases"), equals("database"));
    });

    test("handles uncountable nouns", () {
      uncountableNouns.forEach((noun) {
        expect(SINGULAR.convert(noun), equals(noun));
      });

      uncountableNouns.forEach((noun) {
        final upperNoun = noun.toUpperCase();
        expect(SINGULAR.convert(upperNoun), equals(upperNoun));
      });
    });

    test("handles irregular plural nouns", () {
      expect(SINGULAR.convert("people"), equals("person"));
      expect(SINGULAR.convert("Children"), equals("Child"));
      expect(SINGULAR.convert("child"), equals("child"));
      expect(SINGULAR.convert("men"), equals("man"));
    });
  });
}
