part of lex.src.combinator;

class _ToList<T> extends ListParser<T> {
  final Parser<T> parser;

  _ToList(this.parser);

  @override
  ParseResult<List<T>> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());

    if (result.value is List) {
      return (result as ParseResult<List<T>>).change(parser: this);
    }

    return new ParseResult(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      result.errors,
      span: result.span,
      value: [result.value],
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('to list (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
