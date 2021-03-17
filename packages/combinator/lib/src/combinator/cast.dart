part of lex.src.combinator;

class _Cast<T, U extends T> extends Parser<U> {
  final Parser<T> parser;

  _Cast(this.parser);

  @override
  ParseResult<U> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    return new ParseResult<U>(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      result.errors,
      span: result.span,
      value: result.value as U,
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('cast<$U> (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}

class _CastDynamic<T> extends Parser<dynamic> {
  final Parser<T> parser;

  _CastDynamic(this.parser);

  @override
  ParseResult<dynamic> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    return new ParseResult<dynamic>(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      result.errors,
      span: result.span,
      value: result.value,
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('cast<dynamic> (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
