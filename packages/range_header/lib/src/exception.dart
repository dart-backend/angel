class RangeHeaderParseException extends FormatException {
  final String message;

  RangeHeaderParseException(this.message);

  @override
  String toString() => 'Range header parse exception: $message';
}
