part of lex.src.combinator;

Reference<T> reference<T>() => new Reference<T>._();

class Reference<T> extends Parser<T> {
  Parser<T> _parser;
  bool printed = false;

  Reference._();

  void set parser(Parser<T> value) {
    if (_parser != null)
      throw new StateError(
          'There is already a parser assigned to this reference.');
    _parser = value;
  }

  @override
  ParseResult<T> __parse(ParseArgs args) {
    if (_parser == null)
      throw new StateError('There is no parser assigned to this reference.');
    return _parser._parse(args);
  }

  @override
  ParseResult<T> _parse(ParseArgs args) {
    return _parser._parse(args);
  }

  @override
  void stringify(CodeBuffer buffer) {
    if (_parser == null)
      buffer.writeln('(undefined reference <$T>)');
    else if (!printed) _parser.stringify(buffer);
    printed = true;
    buffer.writeln('(previously printed reference)');
  }
}
