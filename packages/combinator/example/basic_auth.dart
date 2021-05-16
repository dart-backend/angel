// Run this with "Basic QWxhZGRpbjpPcGVuU2VzYW1l"

import 'dart:convert';
import 'dart:io';
import 'package:angel3_combinator/angel3_combinator.dart';
import 'package:string_scanner/string_scanner.dart';

/// Parse a part of a decoded Basic auth string.
///
/// Namely, the `username` or `password` in `{username}:{password}`.
final Parser<String> string =
    match<String>(RegExp(r'[^:$]+'), errorMessage: 'Expected a string.')
        .value((r) => r.span!.text);

/// Transforms `{username}:{password}` to `{"username": username, "password": password}`.
final Parser<Map<String, String>> credentials = chain<String>([
  string.opt(),
  match<String>(':'),
  string.opt(),
]).map<Map<String, String>>(
    (r) => {'username': r.value![0], 'password': r.value![2]});

/// We can actually embed a parser within another parser.
///
/// This is used here to BASE64URL-decode a string, and then
/// parse the decoded string.
final Parser credentialString = match<Map<String, String>?>(
        RegExp(r'([^\n$]+)'),
        errorMessage: 'Expected a credential string.')
    .value((r) {
  var decoded = utf8.decode(base64Url.decode(r.span!.text));
  var scanner = SpanScanner(decoded);
  return credentials.parse(scanner).value;
});

final Parser basic = match<Null>('Basic').space();

final Parser basicAuth = basic.then(credentialString).index(1);

void main() {
  while (true) {
    stdout.write('Enter a basic auth value: ');
    var line = stdin.readLineSync()!;
    var scanner = SpanScanner(line, sourceUrl: 'stdin');
    var result = basicAuth.parse(scanner);

    if (!result.successful) {
      for (var error in result.errors) {
        print(error.toolString);
        print(error.span!.highlight(color: true));
      }
    } else
      print(result.value);
  }
}
