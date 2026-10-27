import 'package:source_span/source_span.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';

import '../members.dart';
import 'expression.dart';
import 'identifier.dart';
import 'token.dart';

/// The name in the scope of the [MemberResolver] given to `Renderer.render`.
const String memberResolverKey = '!members!';

/// The name in the scope of the [Expando] of the `toJson()` of the values
/// of a render, of `Renderer.render`.
const String jsonCacheKey = '!json!';

/// `target.name`, of [readMember]: `null`, rather than throwing, of an
/// unknown member, or of a member of `null`, with `strictResolution: false`.
class MemberExpression extends ChainExpression {
  final Expression expression;
  final Token op;
  final Identifier name;

  MemberExpression(this.expression, this.op, this.name);

  @override
  Object? computeChain(SymbolTable? scope) {
    var target = computeLink(expression, scope);
    if (identical(target, nullShorted)) return nullShorted;
    if (op.span.text == '?.' && target == null) return nullShorted;

    var value = tryReadMember(
      target,
      name.name,
      resolver: scope?.resolve(memberResolverKey)?.value as MemberResolver?,
      jsonCache: scope?.resolve(jsonCacheKey)?.value as Expando<Object>?,
    );
    if (!identical(value, noMember)) return value;
    if (isLenient(scope)) return null;
    throw NoSuchMethodError.withInvocation(
      target,
      Invocation.getter(Symbol(name.name)),
    );
  }

  @override
  FileSpan get span => expression.span.expand(op.span).expand(name.span);
}
