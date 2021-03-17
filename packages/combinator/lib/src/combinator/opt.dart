part of lex.src.combinator;

class _Opt<T> extends Parser<T> {
  final Parser<T> parser;
  final bool backtrack;

  _Opt(this.parser, this.backtrack);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var replay = args.scanner.position;
    var result = parser._parse(args.increaseDepth());

    if (!result.successful) args.scanner.position = replay;

    return result.change(parser: this, successful: true);
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('optional (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}

class _ListOpt<T> extends ListParser<T> {
  final ListParser<T> parser;
  final bool backtrack;

  _ListOpt(this.parser, this.backtrack);

  @override
  ParseResult<List<T>> __parse(ParseArgs args) {
    var replay = args.scanner.position;
    var result = parser._parse(args.increaseDepth());

    if (!result.successful) args.scanner.position = replay;

    return result.change(parser: this, successful: true);
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('optional (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
