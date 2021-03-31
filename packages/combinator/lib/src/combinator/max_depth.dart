part of lex.src.combinator;

class _MaxDepth<T> extends Parser<T> {
  final Parser<T> parser;
  final int cap;

  _MaxDepth(this.parser, this.cap);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    if (args.depth > cap) {
      return new ParseResult<T>(args.trampoline, args.scanner, this, false, []);
    }

    return parser._parse(args.increaseDepth());
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('max depth($cap) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
