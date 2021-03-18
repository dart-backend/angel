import 'dart:io';
import 'package:combinator/combinator.dart';
import 'package:string_scanner/string_scanner.dart';

final Parser<String> id =
    match<String>(RegExp(r'[A-Za-z]+')).value((r) => r.span!.text);

// We can use `separatedBy` to easily construct parser
// that can be matched multiple times, separated by another
// pattern.
//
// This is useful for parsing arrays or map literals.
main() {
  while (true) {
    stdout.write('Enter a string (ex "a,b,c"): ');
    var line = stdin.readLineSync()!;
    var scanner = new SpanScanner(line, sourceUrl: 'stdin');
    var result = id.separatedBy(match(',').space()).parse(scanner)!;

    if (!result.successful) {
      for (var error in result.errors) {
        print(error.toolString);
        print(error.span!.highlight(color: true));
      }
    } else
      print(result.value);
  }
}
