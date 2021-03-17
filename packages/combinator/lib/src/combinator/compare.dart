part of lex.src.combinator;

class _Compare<T> extends ListParser<T> {
  final ListParser<T> parser;
  final Comparator<T> compare;

  _Compare(this.parser, this.compare);

  @override
  ParseResult<List<T>> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    if (!result.successful) return result;

    result = result.change(
        value: result.value?.isNotEmpty == true ? result.value : []);
    result = result.change(value: new List<T>.from(result.value));
    return new ParseResult<List<T>>(
      args.trampoline,
      args.scanner,
      this,
      true,
      [],
      span: result.span,
      value: result.value..sort(compare),
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('sort($compare) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
