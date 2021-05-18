class RangeHeaderParseException extends FormatException {
  @override
  final String message;

  RangeHeaderParseException(this.message);

  @override
  String toString() => 'Range header parse exception: $message';
}

class InvalidRangeHeaderException implements Exception {
  final String message;

  InvalidRangeHeaderException(this.message);

  @override
  String toString() => 'Range header parse exception: $message';
}
