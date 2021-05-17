library inflection3.past.test;

import 'package:inflection3/inflection3.dart';
import 'package:inflection3/src/irregular_past_verbs.dart';
import 'package:test/test.dart';

void main() {
  group('The PastEncoder', () {
    test('converts verbs from present or participle to past', () {
      expect(PAST.convert(''), equals(''));
      expect(PAST.convert('ask'), equals('asked'));
      expect(PAST.convert('close'), equals('closed'));
      expect(PAST.convert('die'), equals('died'));
      expect(PAST.convert('phone'), equals('phoned'));
      expect(PAST.convert('play'), equals('played'));
      expect(PAST.convert('destroy'), equals('destroyed'));
      expect(PAST.convert('show'), equals('showed'));
      expect(PAST.convert('marry'), equals('married'));
      expect(PAST.convert('study'), equals('studied'));
      expect(PAST.convert('visit'), equals('visited'));
      expect(PAST.convert('miss'), equals('missed'));
      expect(PAST.convert('watch'), equals('watched'));
      expect(PAST.convert('finish'), equals('finished'));
      expect(PAST.convert('fix'), equals('fixed'));
      expect(PAST.convert('buzz'), equals('buzzed'));
      expect(PAST.convert('asked'), equals('asked'));
      expect(PAST.convert('closed'), equals('closed'));
      expect(PAST.convert('reopened'), equals('reopened'));
      expect(PAST.convert('unseed'), equals('unseeded'));
    });

    test('handles irregular past verbs', () {
      irregularPastVerbs.forEach((String presentOrParticiple, String past) {
        expect(PAST.convert(presentOrParticiple), equals(past));
      });
      expect(PAST.convert('forgo'), equals('forwent'));
      expect(PAST.convert('undo'), equals('undid'));
      expect(PAST.convert('outsell'), equals('outsold'));
      expect(PAST.convert('rebreed'), equals('rebred'));
      expect(PAST.convert('arose'), equals('arose'));
      expect(PAST.convert('backslid'), equals('backslid'));
      expect(PAST.convert('forbade'), equals('forbade'));
    });
  });
}
