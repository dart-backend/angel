import 'package:angel3_combinator/angel3_combinator.dart';
import 'package:string_scanner/string_scanner.dart';

void main() {
  var pub = match('pub').map((r) => r.span!.text).space();
  var dart = match('dart').map((r) => 24).space();
  var lang = match('lang').map((r) => true).space();

  // Parses a Tuple3<String, int, bool>
  var grammar = tuple3(pub, dart, lang);

  var scanner = SpanScanner('pub dart lang');
  print(grammar.parse(scanner).value);
}
