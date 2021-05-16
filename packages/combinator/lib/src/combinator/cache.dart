part of lex.src.combinator;

class _Cache<T> extends Parser<T> {
  final Map<int, ParseResult<T>> _cache = {};
  final Parser<T> parser;

  _Cache(this.parser);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    return _cache.putIfAbsent(args.scanner.position, () {
      return parser._parse(args.increaseDepth());
    }).change(parser: this);
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('cache(${_cache.length}) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
