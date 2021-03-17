part of lex.src.combinator;

class _Reduce<T> extends Parser<T> {
  final ListParser<T> parser;
  final T Function(T, T) combine;

  _Reduce(this.parser, this.combine);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());

    if (!result.successful)
      return new ParseResult<T>(
        args.trampoline,
        args.scanner,
        this,
        false,
        result.errors,
      );

    result = result.change(
        value: result.value?.isNotEmpty == true ? result.value : []);
    return new ParseResult<T>(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      [],
      span: result.span,
      value: result.value.isEmpty ? null : result.value.reduce(combine),
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('reduce($combine) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
