import 'package:string_scanner/string_scanner.dart';

/// Parses a string into a [RegExp] that is matched against hostnames.
class HostnameSyntaxParser {
  final SpanScanner _scanner;
  final _safe = RegExp(r'[0-9a-zA-Z-_:]+');

  HostnameSyntaxParser(String hostname)
    : _scanner = SpanScanner(hostname, sourceUrl: hostname);

  FormatException _formatExc(String message) {
    var span = _scanner.lastSpan ?? _scanner.emptySpan;
    return FormatException(
      '${span.start.toolString}: $message\n${span.highlight(color: true)}',
    );
  }

  /// Parses whole hostnames separated by `|`, any of which may match (e.g.
  /// `example.com|api.example.com`).
  RegExp parse() {
    if (_scanner.isDone) throw _formatExc('Invalid or empty hostname.');
    var alternatives = [_parseHostname(first: true)];
    while (_scanner.scan('|')) {
      alternatives.add(_parseHostname(first: false));
    }

    var pattern = alternatives.length == 1
        ? alternatives.single
        : alternatives.map((a) => '($a)').join('|');
    return RegExp('^($pattern)\$', caseSensitive: false);
  }

  /// Parses one hostname, up to a `|` or the end.
  String _parseHostname({required bool first}) {
    var b = StringBuffer();
    while (!_scanner.isDone && !_scanner.matches('|')) {
      var (pattern, tookDot) = _parseHostnamePart();
      b.write(pattern);
      // `*.` already took its dot, so a second one is an empty label.
      if (tookDot) continue;
      // A trailing dot (the FQDN form, `example.com.`) is ignored.
      if (_scanner.scan('.') && !_scanner.isDone && !_scanner.matches('|')) {
        b.write('\\.');
      }
    }
    if (b.isEmpty) {
      throw _formatExc(
        first
            ? 'No hostname parts found before "|".'
            : _scanner.isDone
            ? 'No hostname parts found after "|".'
            : 'No hostname parts found between "|"s.',
      );
    }
    return b.toString();
  }

  /// One label or wildcard, and whether it also took the `.` after it.
  (String, bool) _parseHostnamePart() {
    if (_scanner.scan('*.')) {
      return (r'([^$.]+\.)?', true);
    } else if (_scanner.scan('*')) {
      return (r'[^$]*', false);
    } else if (_scanner.scan('+')) {
      return (r'[^$]+', false);
    } else if (_scanner.scan(_safe)) {
      return (_scanner.lastMatch?[0] ?? '', false);
    } else if (!_scanner.isDone) {
      var s = String.fromCharCode(_scanner.peekChar()!);
      throw _formatExc('Unexpected character "$s".');
    } else {
      return ('', false);
    }
  }
}
