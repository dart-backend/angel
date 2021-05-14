import 'package:source_span/source_span.dart';

/// An advanced StringBuffer geared toward generating code, and source maps.
class CodeBuffer implements StringBuffer {
  /// The character sequence used to represent a line break.
  final String newline;

  /// The character sequence used to represent a space/tab.
  final String space;

  /// The source URL to be applied to all generated [SourceSpan] instances.
  final sourceUrl;

  /// If `true` (default: `false`), then an additional [newline] will be inserted at the end of the generated string.
  final bool trailingNewline;

  final List<CodeBufferLine> _lines = [];
  CodeBufferLine? _currentLine, _lastLine;
  int _indentationLevel = 0;
  int _length = 0;

  CodeBuffer(
      {this.space: '  ',
      this.newline: '\n',
      this.trailingNewline: false,
      this.sourceUrl});

  /// Creates a [CodeBuffer] that does not emit additional whitespace.
  factory CodeBuffer.noWhitespace({sourceUrl}) => CodeBuffer(
      space: '', newline: '', trailingNewline: false, sourceUrl: sourceUrl);

  /// The last line created within this buffer.
  CodeBufferLine? get lastLine => _lastLine;

  /// Returns an immutable collection of the [CodeBufferLine]s within this instance.
  List<CodeBufferLine> get lines => List<CodeBufferLine>.unmodifiable(_lines);

  @override
  bool get isEmpty => _lines.isEmpty;

  @override
  bool get isNotEmpty => _lines.isNotEmpty;

  @override
  int get length => _length;

  CodeBufferLine _createLine() {
    var start = SourceLocation(
      _length,
      sourceUrl: sourceUrl,
      line: _lines.length,
      column: _indentationLevel * space.length,
    );
    var line = CodeBufferLine._(_indentationLevel, start).._end = start;
    _lines.add(_lastLine = line);
    return line;
  }

  /// Increments the indentation level.
  void indent() {
    _indentationLevel++;
  }

  /// Decrements the indentation level, if it is greater than `0`.
  void outdent() {
    if (_indentationLevel > 0) _indentationLevel--;
  }

  /// Copies the contents of this [CodeBuffer] into another, preserving indentation and source mapping information.
  void copyInto(CodeBuffer other) {
    if (_lines.isEmpty) return;
    int i = 0;

    for (var line in _lines) {
      // To compute offset:
      //   1. Find current length of other
      //   2. Add length of its newline
      //   3. Add indentation
      var column = (other._indentationLevel + line.indentationLevel) *
          other.space.length;
      var offset = other._length + other.newline.length + column;

      // Re-compute start + end
      var start = SourceLocation(
        offset,
        sourceUrl: other.sourceUrl,
        line: other._lines.length + i,
        column: column,
      );

      var end = SourceLocation(
        offset + line.span.length,
        sourceUrl: other.sourceUrl,
        line: start.line,
        column: column + line._buf.length,
      );

      var clone = CodeBufferLine._(
          line.indentationLevel + other._indentationLevel, start)
        .._end = end
        .._buf.write(line._buf.toString());

      // Adjust lastSpan
      if (line._lastSpan != null) {
        var s = line._lastSpan!.start;
        var lastSpanColumn =
            ((line.indentationLevel + other._indentationLevel) *
                    other.space.length) +
                line.text.indexOf(line._lastSpan!.text);
        clone._lastSpan = SourceSpan(
          SourceLocation(
            offset + s.offset,
            sourceUrl: other.sourceUrl,
            line: clone.span.start.line,
            column: lastSpanColumn,
          ),
          SourceLocation(
            offset + s.offset + line._lastSpan!.length,
            sourceUrl: other.sourceUrl,
            line: clone.span.end.line,
            column: lastSpanColumn + line._lastSpan!.length,
          ),
          line._lastSpan!.text,
        );
      }

      other._lines.add(other._currentLine = other._lastLine = clone);

      // Adjust length accordingly...
      other._length = offset + clone.span.length;
      i++;
    }

    other.writeln();
  }

  @override
  void clear() {
    _lines.clear();
    _length = _indentationLevel = 0;
    _currentLine = null;
  }

  @override
  void writeCharCode(int charCode) {
    _currentLine ??= _createLine();

    _currentLine!._buf.writeCharCode(charCode);
    var end = _currentLine!._end;
    _currentLine!._end = SourceLocation(
      end.offset + 1,
      sourceUrl: end.sourceUrl,
      line: end.line,
      column: end.column + 1,
    );
    _length++;
    _currentLine!._lastSpan =
        SourceSpan(end, _currentLine!._end, String.fromCharCode(charCode));
  }

  @override
  void write(Object? obj) {
    var msg = obj.toString();
    _currentLine ??= _createLine();
    _currentLine!._buf.write(msg);
    var end = _currentLine!._end;
    _currentLine!._end = SourceLocation(
      end.offset + msg.length,
      sourceUrl: end.sourceUrl,
      line: end.line,
      column: end.column + msg.length,
    );
    _length += msg.length;
    _currentLine!._lastSpan = SourceSpan(end, _currentLine!._end, msg);
  }

  @override
  void writeln([Object? obj = ""]) {
    if (obj != null && obj != '') write(obj);
    _currentLine = null;
    _length++;
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    write(objects.join(separator));
  }

  @override
  String toString() {
    var buf = StringBuffer();
    int i = 0;

    for (var line in lines) {
      if (i++ > 0) buf.write(newline);
      for (int j = 0; j < line.indentationLevel; j++) buf.write(space);
      buf.write(line._buf.toString());
    }

    if (trailingNewline == true) buf.write(newline);

    return buf.toString();
  }
}

/// Represents a line of text within a [CodeBuffer].
class CodeBufferLine {
  /// Mappings from one [SourceSpan] to another, to aid with generating dynamic source maps.
  final Map<SourceSpan, SourceSpan> sourceMappings = {};

  /// The level of indentation preceding this line.
  final int indentationLevel;

  final SourceLocation _start;
  final StringBuffer _buf = StringBuffer();
  late SourceLocation _end;
  SourceSpan? _lastSpan;

  CodeBufferLine._(this.indentationLevel, this._start);

  /// The [SourceSpan] corresponding to the last text written to this line.
  SourceSpan? get lastSpan => _lastSpan;

  /// The [SourceSpan] corresponding to this entire line.
  SourceSpan get span => SourceSpan(_start, _end, _buf.toString());

  /// The text within this line.
  String get text => _buf.toString();
}
