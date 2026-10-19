import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:source_span/source_span.dart';

import 'expression.dart';
import 'token.dart';

class BinaryExpression extends Expression {
  final Expression left, right;
  final Token operator;

  BinaryExpression(this.left, this.operator, this.right);

  @override
  dynamic compute(scope) {
    var l = left.compute(scope);

    // Of the right only if the left does not tell the value.
    switch (operator.type) {
      case TokenType.and:
        return _isTrue(l, scope) && _isTrue(right.compute(scope), scope);
      case TokenType.or:
        return _isTrue(l, scope) || _isTrue(right.compute(scope), scope);
      case TokenType.elvis:
        return l ?? right.compute(scope);
      default:
        break;
    }

    var r = right.compute(scope);
    switch (operator.type) {
      case TokenType.asterisk:
        return l * r;
      case TokenType.slash:
        return l / r;
      case TokenType.percent:
        return l % r;
      case TokenType.plus:
        if (l is String || r is String) return l.toString() + r.toString();
        return l + r;
      case TokenType.minus:
        return l - r;
      case TokenType.lt:
        return l < r;
      case TokenType.gt:
        return l > r;
      case TokenType.lte:
        return l <= r;
      case TokenType.gte:
        return l >= r;
      case TokenType.equ:
        return l == r;
      case TokenType.nequ:
        return l != r;
      default:
        throw UnsupportedError(
          'Unsupported binary operator: "${operator.span.text}".',
        );
    }
  }

  /// Whether [value] is `true`: a `bool`, or, with `strictResolution: false`,
  /// anything, of which only `true` is.
  static bool _isTrue(Object? value, SymbolTable? scope) =>
      isLenient(scope) ? value == true : value as bool;

  @override
  FileSpan get span => left.span.expand(operator.span).expand(right.span);
}
