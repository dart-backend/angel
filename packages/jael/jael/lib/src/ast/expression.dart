import 'package:source_span/source_span.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';

import 'ast_node.dart';
import 'token.dart';

abstract class Expression extends AstNode {
  dynamic compute(SymbolTable? scope);
}

/// The value of a link of a chain, `a?.b.c`, after a `?.` of a `null`, which
/// makes the whole chain `null`, as in Dart.
const Object nullShorted = _NullShorted();

class _NullShorted {
  const _NullShorted();

  @override
  String toString() => 'nullShorted';
}

/// A link of a chain of members, calls and indexes, `a?.b().c[0]`, which a
/// `?.` of a `null` before it makes `null`.
abstract class ChainExpression extends Expression {
  /// The value of the chain up to this link, or [nullShorted].
  Object? computeChain(SymbolTable? scope);

  @override
  dynamic compute(SymbolTable? scope) {
    var value = computeChain(scope);
    return identical(value, nullShorted) ? null : value;
  }
}

/// The value of [expression] as the link before another of a chain: of
/// [ChainExpression.computeChain], if it is one.
Object? computeLink(Expression expression, SymbolTable? scope) =>
    expression is ChainExpression
    ? expression.computeChain(scope)
    : expression.compute(scope);

/// Whether the names of [scope] that are not found are `null`, of
/// `strictResolution: false`.
bool isLenient(SymbolTable? scope) =>
    scope?.resolve('!strict!')?.value == false;

abstract class Literal extends Expression {}

class Negation extends Expression {
  final Token exclamation;
  final Expression expression;

  Negation(this.exclamation, this.expression);

  @override
  FileSpan get span {
    return exclamation.span.expand(expression.span);
  }

  @override
  bool compute(SymbolTable? scope) {
    var value = expression.compute(scope);
    return !(isLenient(scope) ? value == true : value as bool);
  }
}
