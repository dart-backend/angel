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

    var values = <T>[];
    if (result.value != null) {
      values.add(result.value!);
    }
    return ParseResult(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      result.errors,
      span: result.span,
      value: values,
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
