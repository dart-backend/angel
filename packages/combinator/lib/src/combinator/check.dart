part of lex.src.combinator;

class _Check<T> extends Parser<T> {
  final Parser<T> parser;
  final Matcher matcher;
  final String errorMessage;
  final SyntaxErrorSeverity severity;

  _Check(this.parser, this.matcher, this.errorMessage, this.severity);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var matchState = {};
    var result = parser._parse(args.increaseDepth()).change(parser: this);
    if (!result.successful)
      return result;
    else if (!matcher.matches(result.value, matchState)) {
      return result.change(successful: false).addErrors([
        new SyntaxError(
          severity,
          errorMessage ??
              matcher.describe(new StringDescription('Expected ')).toString() +
                  '.',
          result.span,
        ),
      ]);
    } else
      return result;
  }

  @override
  void stringify(CodeBuffer buffer) {
    var d = matcher.describe(new StringDescription());
    buffer
      ..writeln('check($d) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
