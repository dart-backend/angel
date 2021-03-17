part of lex.src.combinator;

class _Negate<T> extends Parser<T> {
  final Parser<T> parser;
  final String errorMessage;
  final SyntaxErrorSeverity severity;

  _Negate(this.parser, this.errorMessage, this.severity);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth()).change(parser: this);

    if (!result.successful) {
      return new ParseResult<T>(
        args.trampoline,
        args.scanner,
        this,
        true,
        [],
        span: result.span ?? args.scanner.lastSpan ?? args.scanner.emptySpan,
        value: result.value,
      );
    }

    result = result.change(successful: false);

    if (errorMessage != null) {
      result = result.addErrors([
        new SyntaxError(
          severity,
          errorMessage,
          result.span,
        ),
      ]);
    }

    return result;
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('negate (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
