part of lex.src.combinator;

/*
/// Handles left recursion in a grammar using the Pratt algorithm.
class Recursion<T> {
  Iterable<Parser<T>> prefix;
  Map<Parser, T Function(T, T, ParseResult<T>)> infix;
  Map<Parser, T Function(T, T, ParseResult<T>)> postfix;

  Recursion({this.prefix, this.infix, this.postfix}) {
    prefix ??= [];
    infix ??= {};
    postfix ??= {};
  }

  Parser<T> precedence(int p) => new _Precedence(this, p);

  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('recursion (')
      ..indent()
      ..writeln('prefix(${prefix.length}')
      ..writeln('infix(${infix.length}')
      ..writeln('postfix(${postfix.length}')
      ..outdent()
      ..writeln(')');
  }
}

class _Precedence<T> extends Parser<T> {
  final Recursion r;
  final int precedence;

  _Precedence(this.r, this.precedence);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    int replay = args.scanner.position;
    var errors = <SyntaxError>[];
    var start = args.scanner.state;
    var reversedKeys = r.infix.keys.toList().reversed;

    for (var pre in r.prefix) {
      var result = pre._parse(args.increaseDepth()), originalResult = result;

      if (!result.successful) {
        if (pre is _Alt) errors.addAll(result.errors);
        args.scanner.position = replay;
      } else {
        var left = result.value;
        replay = args.scanner.position;
        //print('${result.span.text}:\n' + scanner.emptySpan.highlight());

        while (true) {
          bool matched = false;

          //for (int i = 0; i < r.infix.length; i++) {
          for (int i = r.infix.length - 1; i >= 0; i--) {
            //var fix = r.infix.keys.elementAt(r.infix.length - i - 1);
            var fix = reversedKeys.elementAt(i);

            if (i < precedence) continue;

            var result = fix._parse(args.increaseDepth());

            if (!result.successful) {
              if (fix is _Alt) errors.addAll(result.errors);
              // If this is the last alternative and it failed, don't continue looping.
              //if (true || i + 1 < r.infix.length)
              args.scanner.position = replay;
            } else {
              //print('FOUND $fix when left was $left');
              //print('$i vs $precedence\n${originalResult.span.highlight()}');
              result = r.precedence(i)._parse(args.increaseDepth());

              if (!result.successful) {
              } else {
                matched = false;
                var old = left;
                left = r.infix[fix](left, result.value, result);
                print(
                    '$old $fix ${result.value} = $left\n${result.span.highlight()}');
                break;
              }
            }
          }

          if (!matched) break;
        }

        replay = args.scanner.position;
        //print('f ${result.span.text}');

        for (var post in r.postfix.keys) {
          var result = pre._parse(args.increaseDepth());

          if (!result.successful) {
            if (post is _Alt) errors.addAll(result.errors);
            args.scanner.position = replay;
          } else {
            left = r.infix[post](left, originalResult.value, result);
          }
        }

        if (!args.scanner.isDone) {
          // If we're not done scanning, then we need some sort of guard to ensure the
          // that this exact parser does not run again in the exact position.
        }
        return new ParseResult(
          args.trampoline,
          args.scanner,
          this,
          true,
          errors,
          value: left,
          span: args.scanner.spanFrom(start),
        );
      }
    }

    return new ParseResult(
      args.trampoline,
      args.scanner,
      this,
      false,
      errors,
      span: args.scanner.spanFrom(start),
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('precedence($precedence) (')
      ..indent();
    r.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
*/
