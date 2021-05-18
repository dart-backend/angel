import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:angel3_combinator/angel3_combinator.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:tuple/tuple.dart';

void main() {
  var expr = reference();
  var symbols = <String, dynamic>{};

  void registerFunction(String name, int nArgs, Function(List<num>) f) {
    symbols[name] = Tuple2(nArgs, f);
  }

  registerFunction('**', 2, (args) => pow(args[0], args[1]));
  registerFunction('*', 2, (args) => args[0] * args[1]);
  registerFunction('/', 2, (args) => args[0] / args[1]);
  registerFunction('%', 2, (args) => args[0] % args[1]);
  registerFunction('+', 2, (args) => args[0] + args[1]);
  registerFunction('-', 2, (args) => args[0] - args[1]);
  registerFunction('.', 1, (args) => args[0].toDouble());
  registerFunction('print', 1, (args) {
    print(args[0]);
    return args[0];
  });

  var number =
      match(RegExp(r'[0-9]+(\.[0-9]+)?'), errorMessage: 'Expected a number.')
          .map((r) => num.parse(r.span!.text));

  var id = match(
          RegExp(
              r'[A-Za-z_!\\$",\\+-\\./:;\\?<>%&\\*@\[\]\\{\}\\|`\\^~][A-Za-z0-9_!\\$",\\+-\\./:;\\?<>%&\*@\[\]\\{\}\\|`\\^~]*'),
          errorMessage: 'Expected an ID')
      .map((r) => symbols[r.span!.text] ??=
          throw "Undefined symbol: '${r.span!.text}'");

  var atom = number.castDynamic().or(id);

  var list = expr.space().times(2, exact: false).map((r) {
    try {
      var out = [];
      var q = Queue.from(r.value!.reversed);

      while (q.isNotEmpty) {
        var current = q.removeFirst();
        if (current is! Tuple2) {
          out.insert(0, current);
        } else {
          var args = [];
          for (var i = 0; i < (current.item1 as num); i++) {
            args.add(out.removeLast());
          }
          out.add(current.item2(args));
        }
      }

      return out.length == 1 ? out.first : out;
    } catch (_) {
      return [];
    }
  });

  expr.parser = longest([
    list,
    atom,
    expr.parenthesized(),
  ]); //list | atom | expr.parenthesized();

  while (true) {
    stdout.write('> ');
    var line = stdin.readLineSync()!;
    var result = expr.parse(SpanScanner(line));

    if (result.errors.isNotEmpty) {
      for (var error in result.errors) {
        print(error.toolString);
        print(error.message);
      }
    } else {
      print(result.value);
    }
  }
}
