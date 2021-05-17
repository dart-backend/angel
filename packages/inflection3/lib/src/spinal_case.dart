//library inflection2.spinal_case;

import 'dart:convert';

final _underscoreRE0 = RegExp(r'''([A-Z\d]+)([A-Z][a-z])''');
final _underscoreRE1 = RegExp(r'''([a-z\d])([A-Z])''');
final _underscoreRE2 = RegExp(r'[_\s]');

class SpinalCaseEncoder extends Converter<String, String> {
  const SpinalCaseEncoder();

  /// Converts the input [phrase] to 'spinal case', i.e. a hyphen-delimited,
  /// lowercase form. Also known as 'kebab case' or 'lisp case'.
  @override
  String convert(String phrase) {
    return phrase
        .replaceAllMapped(_underscoreRE0, (match) => '${match[1]}-${match[2]}')
        .replaceAllMapped(_underscoreRE1, (match) => '${match[1]}-${match[2]}')
        .replaceAll(_underscoreRE2, '-')
        .toLowerCase();
  }
}

const Converter<String, String> SPINAL_CASE = SpinalCaseEncoder();
