import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';
import 'exception.dart';
import 'range_header.dart';
import 'range_header_impl.dart';
import 'range_header_item.dart';

final RegExp _rgxInt = new RegExp(r'[0-9]+');
final RegExp _rgxWs = new RegExp(r'[ \n\r\t]');

enum TokenType { RANGE_UNIT, COMMA, INT, DASH, EQUALS }

class Token {
  final TokenType type;
  final SourceSpan span;

  Token(this.type, this.span);
}

List<Token> scan(String text, List<String> allowedRangeUnits) {
  List<Token> tokens = [];
  var scanner = new SpanScanner(text);

  while (!scanner.isDone) {
    // Skip whitespace
    scanner.scan(_rgxWs);

    if (scanner.scanChar($comma))
      tokens.add(new Token(TokenType.COMMA, scanner.lastSpan));
    else if (scanner.scanChar($dash))
      tokens.add(new Token(TokenType.DASH, scanner.lastSpan));
    else if (scanner.scan(_rgxInt))
      tokens.add(new Token(TokenType.INT, scanner.lastSpan));
    else if (scanner.scanChar($equal))
      tokens.add(new Token(TokenType.EQUALS, scanner.lastSpan));
    else {
      bool matched = false;

      for (var unit in allowedRangeUnits) {
        if (scanner.scan(unit)) {
          tokens.add(new Token(TokenType.RANGE_UNIT, scanner.lastSpan));
          matched = true;
          break;
        }
      }

      if (!matched) {
        var ch = scanner.readChar();
        throw new RangeHeaderParseException(
            'Unexpected character: "${new String.fromCharCode(ch)}"');
      }
    }
  }

  return tokens;
}

class Parser {
  Token _current;
  int _index = -1;
  final List<Token> tokens;

  Parser(this.tokens);

  Token get current => _current;

  bool get done => _index >= tokens.length - 1;

  RangeHeaderParseException _expected(String type) {
    int offset = current?.span?.start?.offset;

    if (offset == null) return new RangeHeaderParseException('Expected $type.');

    Token peek;

    if (_index < tokens.length - 1) peek = tokens[_index + 1];

    if (peek != null && peek.span != null) {
      return new RangeHeaderParseException(
          'Expected $type at offset $offset, found "${peek.span.text}" instead. \nSource:\n${peek.span?.highlight() ?? peek.type}');
    } else
      return new RangeHeaderParseException(
          'Expected $type at offset $offset, but the header string ended without one.\nSource:\n${current.span?.highlight() ?? current.type}');
  }

  bool next(TokenType type) {
    if (done) return false;
    var tok = tokens[_index + 1];
    if (tok.type == type) {
      _index++;
      _current = tok;
      return true;
    } else
      return false;
  }

  RangeHeader parseRangeHeader() {
    if (next(TokenType.RANGE_UNIT)) {
      var unit = current.span.text;
      next(TokenType.EQUALS); // Consume =, if any.

      List<RangeHeaderItem> items = [];
      RangeHeaderItem item = parseHeaderItem();

      while (item != null) {
        items.add(item);
        // Parse comma
        if (next(TokenType.COMMA)) {
          item = parseHeaderItem();
        } else
          item = null;
      }

      if (items.isEmpty)
        throw _expected('range');
      else
        return new RangeHeaderImpl(unit, items);
    } else
      return null;
  }

  RangeHeaderItem parseHeaderItem() {
    if (next(TokenType.INT)) {
      // i.e 500-544, or 600-
      var start = int.parse(current.span.text);
      if (next(TokenType.DASH)) {
        if (next(TokenType.INT)) {
          return new RangeHeaderItem(start, int.parse(current.span.text));
        } else
          return new RangeHeaderItem(start);
      } else
        throw _expected('"-"');
    } else if (next(TokenType.DASH)) {
      // i.e. -599
      if (next(TokenType.INT)) {
        return new RangeHeaderItem(-1, int.parse(current.span.text));
      } else
        throw _expected('integer');
    } else
      return null;
  }
}
