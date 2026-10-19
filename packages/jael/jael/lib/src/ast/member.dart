import 'package:source_span/source_span.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';

import '../members.dart';
import 'expression.dart';
import 'identifier.dart';
import 'token.dart';

/// The name in the scope of the [MemberResolver] given to `Renderer.render`.
const String memberResolverKey = '!members!';

/// `target.name`, of [readMember].
class MemberExpression extends Expression {
  final Expression expression;
  final Token op;
  final Identifier name;

  MemberExpression(this.expression, this.op, this.name);

  @override
  dynamic compute(SymbolTable? scope) {
    var target = expression.compute(scope);
    if (op.span.text == '?.' && target == null) return null;
    return readMember(
      target,
      name.name,
      scope?.resolve(memberResolverKey)?.value as MemberResolver?,
    );
  }

  @override
  FileSpan get span => expression.span.expand(op.span).expand(name.span);
}
