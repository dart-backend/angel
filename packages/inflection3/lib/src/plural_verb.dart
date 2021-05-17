//library inflection2.plural_verb;

import 'dart:convert';

import 'irregular_plural_verbs.dart';
import 'util.dart';

class PluralVerbEncoder extends Converter<String, String> {
  final List<List> _inflectionRules = [];

  PluralVerbEncoder() {
    irregularPluralVerbs.forEach((singular, plural) {
      addInflectionRule(singular, (Match m) => plural);
    });

    [
      [r'e?s$', (Match m) => ''],
      [r'ies$', (Match m) => 'y'],
      [r'([^h|z|o|i])es$', (Match m) => '${m[1]}e'],
      [r'ses$', (Match m) => 's'],
      [r'zzes$', (Match m) => 'zz'],
      [r'([cs])hes$', (Match m) => '${m[1]}h'],
      [r'xes$', (Match m) => 'x'],
      [r'sses$', (Match m) => 'ss']
    ]
        .reversed
        .forEach((rule) => addInflectionRule(rule.first as String, rule.last));
  }

  void addInflectionRule(String singular, dynamic plural) {
    _inflectionRules.add([new RegExp(singular, caseSensitive: false), plural]);
  }

  @override
  String convert(String word) {
    if (!word.isEmpty) {
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

final Converter<String, String> PLURALVERB = new PluralVerbEncoder();
