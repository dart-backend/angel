import 'dart:math';
import 'dart:io';
import 'package:combinator/combinator.dart';
import 'package:string_scanner/string_scanner.dart';

/// Note: This grammar does not handle precedence, for the sake of simplicity.
Parser<num> calculatorGrammar() {
  var expr = reference<num>();

  var number = match<num>(new RegExp(r'-?[0-9]+(\.[0-9]+)?'))
      .value((r) => num.parse(r.span!.text));

  var hex = match<int>(new RegExp(r'0x([A-Fa-f0-9]+)'))
      .map((r) => int.parse(r.scanner.lastMatch![1]!, radix: 16));

  var binary = match<int>(new RegExp(r'([0-1]+)b'))
      .map((r) => int.parse(r.scanner.lastMatch![1]!, radix: 2));

  var alternatives = <Parser<num>>[];

  void registerBinary(String op, num Function(num, num) f) {
    alternatives.add(
      chain<num>([
        expr.space(),
        match<Null>(op).space() as Parser<num>,
        expr.space(),
      ]).map((r) => f(r.value![0], r.value![2])),
    );
  }

  registerBinary('**', (a, b) => pow(a, b));
  registerBinary('*', (a, b) => a * b);
  registerBinary('/', (a, b) => a / b);
  registerBinary('%', (a, b) => a % b);
  registerBinary('+', (a, b) => a + b);
  registerBinary('-', (a, b) => a - b);
  registerBinary('^', (a, b) => a.toInt() ^ b.toInt());
  registerBinary('&', (a, b) => a.toInt() & b.toInt());
  registerBinary('|', (a, b) => a.toInt() | b.toInt());

  alternatives.addAll([
    number,
    hex,
    binary,
    expr.parenthesized(),
  ]);

  expr.parser = longest(alternatives);

  return expr;
}

void main() {
  var calculator = calculatorGrammar();

  while (true) {
    stdout.write('Enter an expression: ');
    var line = stdin.readLineSync()!;
    var scanner = new SpanScanner(line, sourceUrl: 'stdin');
    var result = calculator.parse(scanner);

    if (!result.successful) {
      for (var error in result.errors) {
        stderr.writeln(error.toolString);
        stderr.writeln(error.span!.highlight(color: true));
      }
    } else
      print(result.value);
  }
}
