//library inflection2.plural;

import 'dart:convert';

import 'uncountable_nouns.dart';
import 'irregular_plural_nouns.dart';
import 'util.dart';

class PluralEncoder extends Converter<String, String> {
  final List<List> _inflectionRules = [];

  PluralEncoder() {
    irregularPluralNouns.forEach((singular, plural) {
      addIrregularInflectionRule(singular, plural);
    });

    [
      [r'$', (Match m) => 's'],
      [r's$', (Match m) => 's'],
      [r'^(ax|test)is$', (Match m) => '${m[1]}es'],
      [r'(octop|vir)us$', (Match m) => '${m[1]}i'],
      [r'(octop|vir)i$', (Match m) => m[0]],
      [r'(alias|status)$', (Match m) => '${m[1]}es'],
      [r'(bu)s$', (Match m) => '${m[1]}ses'],
      [r'(buffal|tomat)o$', (Match m) => '${m[1]}oes'],
      [r'([ti])um$', (Match m) => '${m[1]}a'],
      [r'([ti])a$', (Match m) => m[0]],
      [r'sis$', (Match m) => 'ses'],
      [r'(?:([^f])fe|([lr])f)$', (Match m) => '${m[1]}${m[2]}ves'],
      [r'([^aeiouy]|qu)y$', (Match m) => '${m[1]}ies'],
      [r'(x|ch|ss|sh)$', (Match m) => '${m[1]}es'],
      [r'(matr|vert|ind)(?:ix|ex)$', (Match m) => '${m[1]}ices'],
      [r'^(m|l)ouse$', (Match m) => '${m[1]}ice'],
      [r'^(m|l)ice$', (Match m) => m[0]],
      [r'^(ox)$', (Match m) => '${m[1]}en'],
      [r'^(oxen)$', (Match m) => m[1]],
      [r'(quiz)$', (Match m) => '${m[1]}zes']
    ]
        .reversed
        .forEach((rule) => addInflectionRule(rule.first as String, rule.last));
  }

  void addInflectionRule(String singular, dynamic plural) {
    _inflectionRules.add([RegExp(singular, caseSensitive: false), plural]);
  }

  void addIrregularInflectionRule(String singular, String plural) {
    final s0 = singular.substring(0, 1);
    final srest = singular.substring(1);
    final p0 = plural.substring(0, 1);
    final prest = plural.substring(1);

    if (s0.toUpperCase() == p0.toUpperCase()) {
      addInflectionRule('($s0)$srest\$', (Match m) => '${m[1]}$prest');
      addInflectionRule('($p0)$prest\$', (Match m) => '${m[1]}$prest');
    } else {
      addInflectionRule('${s0.toUpperCase()}(?i)$srest\$',
          (Match m) => '${p0.toUpperCase()}$prest');
      addInflectionRule('${s0.toLowerCase()}(?i)$srest\$',
          (Match m) => '${p0.toUpperCase()}$prest');
      addInflectionRule('${p0.toUpperCase()}(?i)$prest\$',
          (Match m) => '${p0.toUpperCase()}$prest');
      addInflectionRule('${p0.toLowerCase()}(?i)$prest\$',
          (Match m) => '${p0.toLowerCase()}$prest');
    }
  }

  @override
  String convert(String word) {
    if (word.isNotEmpty) {
      if (uncountableNouns.contains(word.toLowerCase())) {
        return word;
      } else {
        for (var r in _inflectionRules) {
          var pattern = r.first as RegExp;
          if (pattern.hasMatch(word)) {
            return word.replaceAllMapped(pattern, r.last as MatchToString);
          }
        }
      }
    }

    return word;
  }
}

final Converter<String, String> PLURAL = PluralEncoder();
