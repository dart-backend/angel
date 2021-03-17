part of lex.src.combinator;

class _Value<T> extends Parser<T> {
  final Parser<T> parser;
  final T Function(ParseResult<T>) f;

  _Value(this.parser, this.f);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth()).change(parser: this);
    return result.successful ? result.change(value: f(result)) : result;
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('set value($f) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
