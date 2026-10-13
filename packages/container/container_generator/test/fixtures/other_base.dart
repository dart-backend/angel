const _baseRetries = 5;

/// A superclass in another library, with a default that names one of its
/// private constants.
class RetryBase {
  final int retries;

  RetryBase({this.retries = _baseRetries});
}
