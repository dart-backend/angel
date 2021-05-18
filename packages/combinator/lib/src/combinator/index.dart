part of lex.src.combinator;

class _Index<T> extends Parser<T> {
  final ListParser<T> parser;
  final int index;

  _Index(this.parser, this.index);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    Object? value;

    if (result.successful) {
      var vList = result.value;
      if (vList == null) {
        throw ArgumentError('ParseResult is null');
      }
      if (index == -1) {
        value = vList.last;
      } else {
        if (index < vList.length) {
//          print(">>>>Index: $index, Size: ${vList.length}");
//        value =
//            index == -1 ? result.value!.last : result.value!.elementAt(index);
          value = result.value!.elementAt(index);
        }
      }
    }

    return ParseResult<T>(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      result.errors,
      span: result.span,
      value: value as T?,
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('index($index) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
