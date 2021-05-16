//library inflection2.past;

import 'dart:convert';

import 'irregular_past_verbs.dart';
import 'verbs_ending_with_ed.dart';
import 'util.dart';

class PastEncoder extends Converter<String, String> {
  final List<List> _inflectionRules = [];

  PastEncoder() {
    irregularPastVerbs.forEach((String presentOrParticiple, String past) {
      addIrregularInflectionRule(presentOrParticiple, past);
    });
    [
      [r'.+', (Match m) => '${m[0]}ed'],
      [r'([^aeiou])y$', (Match m) => '${m[1]}ied'],
      [r'([aeiou]e)$', (Match m) => '${m[1]}d'],
      [r'[aeiou][^aeiou]e$', (Match m) => '${m[0]}d']
    ]
        .reversed
        .forEach((rule) => addInflectionRule(rule.first as String, rule.last));
  }

  void addInflectionRule(String presentOrParticiple, dynamic past) {
    _inflectionRules
        .add([new RegExp(presentOrParticiple, caseSensitive: false), past]);
  }

  void addIrregularInflectionRule(String presentOrParticiple, String past) {
    _inflectionRules.add([
      new RegExp(
          r'^(back|dis|for|fore|in|inter|mis|off|over|out|par|pre|re|type|un|under|up)?' +
              presentOrParticiple +
              r'$',
          caseSensitive: false),
      (Match m) => (m[1] == null) ? past : m[1]! + past
    ]);
  }

  @override
  String convert(String word) {
    if (!word.isEmpty) {
      if (word.contains("ed", word.length - 2)) {
        RegExp reg = new RegExp(
            r'^(back|dis|for|fore|in|inter|mis|off|over|out|par|pre|re|type|un|under|up)(.+)$');
        if (reg.hasMatch(word)) {
          if (!verbsEndingWithEd.contains(reg.firstMatch(word)!.group(2)))
            return word;
        } else if (!verbsEndingWithEd.contains(word)) {
          return word;
        }
      }

      for (var r in _inflectionRules) {
        var pattern = r.first as RegExp;
        if (pattern.hasMatch(word)) {
          return word.replaceAllMapped(pattern, r.last as MatchToString);
        }
      }
    }

    return word;
  }
}

final Converter<String, String> PAST = new PastEncoder();
