//library inflection2.singular_verb;

import 'dart:convert';

import 'irregular_plural_verbs.dart';
import 'util.dart';

class SingularVerbEncoder extends Converter<String, String> {
  final List<List> _inflectionRules = [];

  SingularVerbEncoder() {
    irregularPluralVerbs.forEach((singular, plural) {
      addInflectionRule(plural, (Match m) => singular);
    });

    [
      [r'$', (Match m) => 's'],
      [r'([^aeiou])y$', (Match m) => '${m[1]}ies'],
      [r'(z)$', (Match m) => '${m[1]}es'],
      [r'(ss|zz|x|h|o|us)$', (Match m) => '${m[1]}es'],
      [r'(ed)$', (Match m) => '${m[1]}']
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

final Converter<String, String> SINGULARVERB = new SingularVerbEncoder();
