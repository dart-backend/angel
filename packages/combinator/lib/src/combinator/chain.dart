part of lex.src.combinator;

/// Expects to parse a sequence of [parsers].
///
/// If [failFast] is `true` (default), then the first failure to parse will abort the parse.
ListParser<T> chain<T>(Iterable<Parser<T>> parsers,
    {bool failFast: true, SyntaxErrorSeverity? severity}) {
  return _Chain<T>(
      parsers, failFast != false, severity ?? SyntaxErrorSeverity.error);
}

class _Alt<T> extends Parser<T> {
  final Parser<T> parser;
  final String? errorMessage;
  final SyntaxErrorSeverity severity;

  _Alt(this.parser, this.errorMessage, this.severity);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    return result.successful
        ? result
        : result.addErrors([
            SyntaxError(
                severity, errorMessage, result.span ?? args.scanner.emptySpan),
          ]);
  }

  @override
  void stringify(CodeBuffer buffer) {
    parser.stringify(buffer);
  }
}

class _Chain<T> extends ListParser<T> {
  final Iterable<Parser<T>> parsers;
  final bool failFast;
  final SyntaxErrorSeverity severity;

  _Chain(this.parsers, this.failFast, this.severity);

  @override
  ParseResult<List<T>> __parse(ParseArgs args) {
    var errors = <SyntaxError>[];
    var results = <T>[];
    var spans = <FileSpan>[];
    bool successful = true;

    for (var parser in parsers) {
      var result = parser._parse(args.increaseDepth());

      if (!result.successful) {
        if (parser is _Alt) errors.addAll(result.errors);

        if (failFast) {
          return ParseResult(
              args.trampoline, args.scanner, this, false, result.errors);
        }

        successful = false;
      }

      //TODO: To be looked at
      if (result.value != null) {
        //print(result.value.runtimeType);
        results.add(result.value!);
      } else {
        //print("Add NULL");
        // Add dummy "NULL" String
        results.add("NULL" as T);
      }

      if (result.span != null) {
        spans.add(result.span!);
      }
    }

    FileSpan? span;

    if (spans.isNotEmpty) {
      span = spans.reduce((a, b) => a.expand(b));
    }

    return ParseResult<List<T>>(
      args.trampoline,
      args.scanner,
      this,
      successful,
      errors,
      span: span,
      value: List<T>.unmodifiable(results),
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('chain(${parsers.length}) (')
      ..indent();
    int i = 1;

    for (var parser in parsers) {
      buffer
        ..writeln('#${i++}:')
        ..indent();
      parser.stringify(buffer);
      buffer.outdent();
    }

    buffer
      ..outdent()
      ..writeln(')');
  }
}
