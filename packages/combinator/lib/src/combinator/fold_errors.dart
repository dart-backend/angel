part of lex.src.combinator;

class _FoldErrors<T> extends Parser<T> {
  final Parser<T> parser;
  final bool Function(SyntaxError, SyntaxError) equal;

  _FoldErrors(this.parser, this.equal);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth()).change(parser: this);
    var errors = result.errors.fold<List<SyntaxError>>([], (out, e) {
      if (!out.any((b) => equal(e, b))) out.add(e);
      return out;
    });
    return result.change(errors: errors);
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('fold errors (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
