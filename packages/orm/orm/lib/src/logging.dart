import 'package:logging/logging.dart';

/// Whether the program runs in debug mode: with assertions enabled, as with
/// `dart test`, `dart run --enable-asserts` or a Flutter debug build.
final bool debugMode = () {
  var enabled = false;
  assert(enabled = true);
  return enabled;
}();

/// Logs the [values] of a query at `FINE`, in [debugMode] only: they may be
/// passwords or personal data, which must not reach the logs of a program in
/// production. Executors log the values of their queries with it too.
void logValues(Logger log, Map<String, dynamic> values) {
  if (debugMode) log.fine(() => 'values = $values');
}
