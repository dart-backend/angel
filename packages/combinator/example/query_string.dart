// For some reason, this cannot be run in checked mode???

import 'dart:io';
import 'package:combinator/combinator.dart';
import 'package:string_scanner/string_scanner.dart';

final Parser<String> key =
    match<String>(RegExp(r'[^=&\n]+'), errorMessage: 'Missing k/v')
        .value((r) => r.span!.text);

final Parser value = key.map((r) => Uri.decodeQueryComponent(r.value!));

final Parser pair = chain([
  key,
  match('='),
  value,
]).map((r) {
  return {
    r.value![0]: r.value![2],
  };
});

final Parser pairs = pair
    .separatedBy(match(r'&'))
    .map((r) => r.value!.reduce((a, b) => a..addAll(b)));

final Parser queryString = pairs.opt();

main() {
  while (true) {
    stdout.write('Enter a query string: ');
    var line = stdin.readLineSync()!;
    var scanner = new SpanScanner(line, sourceUrl: 'stdin');
    var result = pairs.parse(scanner)!;

    if (!result.successful) {
      for (var error in result.errors) {
        print(error.toolString);
        print(error.span!.highlight(color: true));
      }
    } else
      print(result.value);
  }
}
