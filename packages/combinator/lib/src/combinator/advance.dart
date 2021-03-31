part of lex.src.combinator;

class _Advance<T> extends Parser<T> {
  final Parser<T> parser;
  final int amount;

  _Advance(this.parser, this.amount);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth()).change(parser: this);
    if (result.successful) args.scanner.position += amount;
    return result;
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('advance($amount) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
