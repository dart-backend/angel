part of 'router.dart';

/// Thrown while parsing a path whose parameter cannot be read (invalid
/// percent-encoding, or not a number for a typed parameter). The route then
/// does not match, rather than failing the whole resolution.
class _NoMatch implements Exception {
  const _NoMatch();
}

String _decode(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    throw const _NoMatch();
  } on FormatException {
    // e.g. `%FF`, which is not UTF-8
    throw const _NoMatch();
  }
}

class RouteGrammar {
  static const String notSlashRgx = r'([^/]+)';
  //static final RegExp rgx = RegExp(r'\((.+)\)');
  static final Parser<String> notSlash = match<String>(RegExp(notSlashRgx))
      .value((r) => r.span?.text ?? '');

  /// An inline RegExp in parentheses, which may itself contain groups
  /// (nested up to two levels), followed by optional literal text.
  static final Parser<Match> regExp = match<Match>(
    RegExp(r'\(((?:[^()\n]|\((?:[^()\n]|\([^()\n]*\))*\))+)\)([^/]+)?'),
  ).value((r) => r.scanner.lastMatch!);

  /// A parameter name, with optional literal text before and after it. The
  /// text after it stops before a `?` (optional) or `(` (RegExp).
  static final Parser<Match> parameterName = match<Match>(
    RegExp(
      '$notSlashRgx?'
      r':([A-Za-z0-9_]+)'
      r'([^(/\n?]+)?',
    ),
  ).value((r) => r.scanner.lastMatch!);

  static final Parser<ParameterSegment> parameterSegment =
      // Nullable, as the optional elements give no value when absent.
      chain<Object?>([
        parameterName,
        match<bool>('?').value((r) => true).opt(),
        regExp.opt(),
      ]).map((r) {
        var match = r.value![0] as Match;

        var rgxMatch = r.value![2] as Match?;

        // Text around the parameter is literal. The value is always group 1.
        var pre = RegExp.escape(match[1] ?? '');
        var post = RegExp.escape(match[3] ?? '');
        String? inner;

        if (rgxMatch != null) {
          inner = rgxMatch[1];
          post = RegExp.escape(rgxMatch[2] ?? '') + post;
        }

        RegExp? rgx;
        (String, String, String)? parts;
        if (inner != null || pre.isNotEmpty || post.isNotEmpty) {
          parts = (pre, inner ?? '[^/]+', post);
          rgx = RegExp('$pre(${parts.$2})$post');
        }

        // TODO: relook at this later
        var m2 = match[2] ?? '';
        var s = ParameterSegment(m2, rgx).._parts = parts;
        return r.value![1] == true ? OptionalSegment(s) : s;
      });

  static final Parser<ParsedParameterSegment> parsedParameterSegment =
      chain([
        match(
          RegExp(r'(int|num|double)'),
          errorMessage: 'Expected "int","double", or "num".',
        ).map((r) => r.span!.text),
        parameterSegment,
      ]).map((r) {
        return ParsedParameterSegment(
          r.value![0] as String,
          r.value![1] as ParameterSegment,
        );
      });

  static final Parser<WildcardSegment> wildcardSegment =
      match<WildcardSegment>(
        RegExp(
          '$notSlashRgx?'
          r'\*'
          '$notSlashRgx?',
        ),
      ).value((r) {
        var m = r.scanner.lastMatch!;
        var pre = m[1] ?? '';
        var post = m[2] ?? '';
        return WildcardSegment(pre, post);
      });

  static final Parser<ConstantSegment> constantSegment = notSlash
      .map<ConstantSegment>((r) => ConstantSegment(r.value));

  static final Parser<SlashSegment> slashSegment = match(SlashSegment.rgx)
      .map((_) => SlashSegment());

  static final Parser<RouteSegment> routeSegment = any([
    //slashSegment,
    parsedParameterSegment,
    parameterSegment,
    wildcardSegment,
    constantSegment,
  ]);

  // static final Parser<RouteDefinition> routeDefinition = routeSegment
  //     .star()
  //     .map<RouteDefinition>((r) => RouteDefinition(r.value ?? []))
  //     .surroundedBy(match(RegExp(r'/*')).opt());

  static final Parser slashes = match(RegExp(r'/*'));

  static final Parser<RouteDefinition> routeDefinition = routeSegment
      .separatedBy(slashes)
      .map<RouteDefinition>((r) => RouteDefinition(r.value ?? []))
      .surroundedBy(slashes.opt());
}

class RouteDefinition {
  final List<RouteSegment> segments;

  RouteDefinition(this.segments);

  Parser<RouteResult>? compile() {
    Parser<RouteResult>? out;

    for (var i = 0; i < segments.length; i++) {
      var s = segments[i];
      var isLast = i == segments.length - 1;
      if (out == null) {
        out = s.compile(isLast);
      } else if (s is OptionalSegment) {
        // Its leading slash is optional too.
        out = s.compileNext(out, isLast);
      } else {
        out = s.compileNext(
          out.then(match('/')).index(0).cast<RouteResult>(),
          isLast,
        );
      }
    }

    return out;
  }

  /// This route as a single [RegExp] that matches a path as [compile]'s
  /// parser does, or `null` if it cannot be written as one.
  ///
  /// The parser never backtracks: each segment takes the first match of its
  /// pattern, and the next segment goes on from there. Each segment is
  /// therefore an atomic group, `(?=(?<g>…))\k<g>`, which takes the first
  /// match of what it contains and is not entered again, so that the whole
  /// [RegExp] cannot match a path differently. Values are read from named
  /// groups, since an inline pattern may have groups of its own.
  _RouteRegExp? _compileRegExp() {
    var pattern = StringBuffer();
    var captures = <_Capture>[];
    var groups = 0;

    String atomic(String body) {
      var group = '_a${groups++}';
      return '(?=(?<$group>$body))\\k<$group>';
    }

    for (var i = 0; i < segments.length; i++) {
      var s = segments[i];
      var type = s.runtimeType;
      if (type == ConstantSegment) {
        if (i > 0) pattern.write('/');
        pattern.write(RegExp.escape((s as ConstantSegment).text!));
      } else if (type == ParameterSegment || type == ParsedParameterSegment) {
        var parameter = s is ParsedParameterSegment
            ? s.parameter
            : s as ParameterSegment;
        var group = '_v${captures.length}';
        var body = _valuePattern(parameter, group);
        if (body == null) return null;
        if (i > 0) pattern.write('/');
        pattern.write(atomic(body));
        captures.add(
          _Capture(
            group,
            name: parameter.name,
            parsed: s is ParsedParameterSegment ? s : null,
          ),
        );
      } else if (type == OptionalSegment) {
        var optional = s as OptionalSegment;
        var group = '_v${captures.length}';
        var body = _valuePattern(optional, group);
        if (body == null) return null;
        // Its leading slash is optional too; the value is tried first.
        pattern.write(atomic(i > 0 ? '(?:/$body)|' : '(?:$body)|'));
        captures.add(_Capture(group, name: optional.name));
      } else if (type == WildcardSegment) {
        var wildcard = s as WildcardSegment;
        // The text around `*` is used as a pattern, unescaped: one with
        // groups or escapes is left to the parser.
        if (!_isPlain(wildcard.pre) || !_isPlain(wildcard.post)) return null;
        var group = '_t${captures.length}';
        var symbol = wildcard._symbol(i == segments.length - 1);
        if (i > 0) pattern.write('/');
        pattern.write(
          atomic('${wildcard.pre}(?<$group>$symbol)${wildcard.post}'),
        );
        captures.add(_Capture(group));
      } else {
        return null;
      }
    }

    try {
      return _RouteRegExp(RegExp(pattern.toString()), captures);
    } on FormatException {
      return null;
    }
  }

  /// The pattern of [parameter]'s value, in a group named [group], or `null`
  /// if its inline pattern cannot be used inside another [RegExp].
  static String? _valuePattern(ParameterSegment parameter, String group) {
    if (parameter is OptionalSegment) parameter = parameter.parameter;
    if (parameter.regExp == null) return '(?<$group>[^/]+)';
    var parts = parameter._parts;
    if (parts == null) return null;
    var (pre, inner, post) = parts;
    // Backreferences and named groups would refer to other groups, or
    // clash, once the pattern is part of a larger one.
    if (inner.contains(_backReferenceOrName)) return null;
    return '$pre(?<$group>$inner)$post';
  }

  static final RegExp _backReferenceOrName = RegExp(
    r'\\[1-9k]|\(\?<[A-Za-z_$]',
  );

  static bool _isPlain(String text) => !text.contains(RegExp(r'[\\()\[\]|]'));
}

/// What a [_RouteRegExp] reads from a match: a parameter's value, or a
/// wildcard's tail if [name] is `null`.
class _Capture {
  final String group;
  final String? name;
  final ParsedParameterSegment? parsed;

  const _Capture(this.group, {this.name, this.parsed});
}

/// A [Route] compiled to a single [RegExp], which gives the same results as
/// its parser, faster (see [RouteDefinition._compileRegExp]).
class _RouteRegExp {
  final RegExp regExp;
  final List<_Capture> captures;

  _RouteRegExp(this.regExp, this.captures);

  /// Never used to parse: a [ParseResult] needs one.
  static final Trampoline _trampoline = Trampoline();

  /// Matches at the [scanner]'s position, and on success moves it past the
  /// match, as [parser] would. Returns `null` if the route does not match.
  ParseResult<RouteResult>? parse(
    Parser<RouteResult> parser,
    SpanScanner scanner,
  ) {
    var start = scanner.state;
    var match =
        regExp.matchAsPrefix(scanner.string, scanner.position) as RegExpMatch?;
    if (match == null) return null;

    var params = <String, dynamic>{};
    String? tail;
    try {
      for (var capture in captures) {
        var text = match.namedGroup(capture.group);
        // An optional parameter that is absent.
        if (text == null) continue;
        var name = capture.name;
        if (name == null) {
          tail ??= text;
        } else {
          var parsed = capture.parsed;
          params[name] = parsed != null
              ? parsed.getValue(_decode(text))
              : _decode(text);
        }
      }
    } on _NoMatch {
      return null;
    }

    scanner.position = match.end;
    return ParseResult<RouteResult>(
      _trampoline,
      scanner,
      parser,
      true,
      const [],
      span: scanner.spanFrom(start),
      value: RouteResult(params, tail: tail),
    );
  }
}

abstract class RouteSegment {
  Parser<RouteResult> compile(bool isLast);

  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast);
}

class SlashSegment implements RouteSegment {
  static final RegExp rgx = RegExp(r'/+');

  const SlashSegment();

  @override
  Parser<RouteResult> compile(bool isLast) {
    return match(rgx).map((_) => RouteResult({}));
  }

  @override
  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast) {
    return p.then(compile(isLast)).index(0).cast<RouteResult>();
  }

  @override
  String toString() => 'Slash';
}

class ConstantSegment extends RouteSegment {
  final String? text;

  ConstantSegment(this.text);

  @override
  String toString() {
    return 'Constant: $text';
  }

  @override
  Parser<RouteResult> compile(bool isLast) {
    return match(text!).map((r) => RouteResult({}));
  }

  @override
  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast) {
    return p.then(compile(isLast)).index(0).cast<RouteResult>();
  }
}

class WildcardSegment extends RouteSegment {
  final String pre, post;

  WildcardSegment(this.pre, this.post);

  @override
  String toString() {
    return 'Wildcard segment';
  }

  String _symbol(bool isLast) {
    if (isLast) return r'.*';
    return r'[^/]*';
  }

  RegExp _compile(bool isLast) {
    return RegExp('$pre(${_symbol(isLast)})$post');
    // if (isLast) return match(RegExp(r'.*'));
    // return match(RegExp(r'[^/]*'));
  }

  @override
  Parser<RouteResult> compile(bool isLast) {
    return match(_compile(isLast)).map((r) {
      var result = r.scanner.lastMatch;
      if (result != null) {
        //return RouteResult({}, tail: r.scanner.lastMatch![1])
        return RouteResult({}, tail: result[1]);
      } else {
        return RouteResult({});
      }
    });
  }

  @override
  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast) {
    return p.then(compile(isLast)).map((r) {
      var items = r.value!.cast<RouteResult>();
      var a = items[0], b = items[1];
      return a
        ..addAll(b.params)
        .._setTail(b.tail);
    });
  }
}

class OptionalSegment extends ParameterSegment {
  final ParameterSegment parameter;

  OptionalSegment(this.parameter) : super(parameter.name, parameter.regExp);

  @override
  String toString() {
    return 'Optional: $parameter';
  }

  @override
  Parser<RouteResult> compile(bool isLast) {
    return super.compile(isLast).opt().map((r) => r.value ?? RouteResult({}));
  }

  /// Unlike other segments, [p] does not include the slash before this one,
  /// since that is optional too.
  @override
  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast) {
    // An absent value is `false` rather than null, which `chain` would
    // replace with the string 'NULL', indistinguishable from a real value.
    var present = match('/').then(_compile()).index(1);
    var absent = match<bool>('').map((_) => false);
    return p.then(any<dynamic>([present, absent])).map((r) {
      var result = r.value![0] as RouteResult;
      var value = r.value![1];
      if (value is String) result.addAll({name: _decode(value)});
      return result;
    });
  }
}

class ParameterSegment extends RouteSegment {
  final String name;
  final RegExp? regExp;

  /// What [regExp] was made of, when parsed from a route: the text before
  /// the value (escaped), the pattern of the value, and the text after it
  /// (escaped). [RouteDefinition._compileRegExp] needs them.
  (String, String, String)? _parts;

  ParameterSegment(this.name, this.regExp);

  @override
  String toString() {
    if (regExp != null) {
      return 'Param: $name (${regExp?.pattern})';
    }
    return 'Param: $name';
  }

  Parser<String> _compile() {
    if (regExp != null) {
      return match<String>(regExp!).value((r) => r.scanner.lastMatch?[1] ?? '');
    } else {
      return RouteGrammar.notSlash;
    }
  }

  @override
  Parser<RouteResult> compile(bool isLast) {
    return _compile().map((r) => RouteResult({name: _decode(r.value!)}));
  }

  @override
  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast) {
    return p.then(_compile()).map((r) {
      return (r.value![0] as RouteResult)
        ..addAll({name: _decode(r.value![1] as String)});
    });
  }
}

class ParsedParameterSegment extends RouteSegment {
  final String type;
  final ParameterSegment parameter;

  ParsedParameterSegment(this.type, this.parameter);

  num getValue(String s) {
    var value = switch (type) {
      'int' => int.tryParse(s),
      'double' => double.tryParse(s),
      _ => num.tryParse(s),
    };
    return value ?? (throw const _NoMatch());
  }

  @override
  Parser<RouteResult> compile(bool isLast) {
    return parameter._compile().map(
      (r) => RouteResult({parameter.name: getValue(_decode(r.value!))}),
    );
  }

  @override
  Parser<RouteResult> compileNext(Parser<RouteResult> p, bool isLast) {
    return p.then(parameter._compile()).map((r) {
      return (r.value![0] as RouteResult)
        ..addAll({parameter.name: getValue(_decode(r.value![1] as String))});
    });
  }
}
