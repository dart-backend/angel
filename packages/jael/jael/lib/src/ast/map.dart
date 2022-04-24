import 'package:source_span/source_span.dart';
import 'ast_node.dart';
import 'expression.dart';
import 'identifier.dart';
import 'token.dart';

class MapLiteral extends Literal {
  final Token lCurly, rCurly;
  final List<KeyValuePair> pairs;

  MapLiteral(this.lCurly, this.pairs, this.rCurly);

  @override
  Map compute(scope) {
    return pairs.fold<Map>({}, (out, p) {
      dynamic key;
      dynamic value;

      if (p.colon == null) {
        if (p.key is! Identifier) {
          key = value = p.key.compute(scope);
        } else {
          key = (p.key as Identifier).name;
          value = p.key.compute(scope);
        }
      } else {
        key = p.key.compute(scope);
        value = p.value?.compute(scope);
      }

      return out..[key] = value;
    });
  }

  @override
  FileSpan get span {
    return pairs
        .fold<FileSpan?>(lCurly.span, (out, p) => out?.expand(p.span))!
        .expand(rCurly.span);
  }
}

class KeyValuePair extends AstNode {
  final Expression key;
  final Expression? value;

  final Token? colon;

  KeyValuePair(this.key, this.colon, this.value);

  @override
  FileSpan get span {
    if (colon == null || value == null) return key.span;
    return colon!.span.expand(colon!.span).expand(value!.span);
  }
}
