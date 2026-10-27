import 'package:source_span/source_span.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';

import 'expression.dart';
import 'token.dart';

class Identifier extends Expression {
  late Token id;

  Identifier(this.id);

  // TODO: Fix for SyntheticIdentifier
  Identifier.noToken(Token? token) {
    if (token != null) {
      id = token;
    }
  }

  @override
  dynamic compute(SymbolTable? scope) {
    switch (name) {
      case 'null':
        return null;
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        var symbol = scope?.resolve(name);
        if (symbol == null) {
          if (isLenient(scope)) return null;
          throw ArgumentError('The name "$name" does not exist in this scope.');
        }
        return symbol.value;
    }
  }

  String get name => id.span.text;

  @override
  FileSpan get span => id.span;
}

class SyntheticIdentifier extends Identifier {
  @override
  final String name;

  final Token? _token;

  SyntheticIdentifier(this.name, [Token? token])
    : _token = token,
      super.noToken(token);

  /// That of its token, if it has one, or else of its [name], in a file of
  /// its own, as it is not in the template.
  @override
  FileSpan get span =>
      _token?.span ??
      SourceFile.fromString(name, url: 'synthetic').span(0, name.length);
}
