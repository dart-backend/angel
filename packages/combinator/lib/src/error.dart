import 'package:source_span/source_span.dart';

class SyntaxError implements Exception {
  final SyntaxErrorSeverity severity;
  final String message;
  final FileSpan span;
  String _toolString;

  SyntaxError(this.severity, this.message, this.span);

  String get toolString {
    if (_toolString != null) return _toolString;
    var type = severity == SyntaxErrorSeverity.warning ? 'warning' : 'error';
    return _toolString = '$type: ${span.start.toolString}: $message';
  }
}

enum SyntaxErrorSeverity {
  warning,
  error,
  info,
  hint,
}
