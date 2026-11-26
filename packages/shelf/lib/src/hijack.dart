import 'dart:async';

import 'package:shelf/shelf.dart' as shelf;

/// Of each request `convertRequest` made, a [Future] that completes once a
/// handler's hijack of it is done.
///
/// `shelf.Request.hijack` throws a `shelf.HijackException` at once, but runs
/// the hijack in a microtask, after which the response is detached. Until
/// then the framework, which the exception returns to, must not send the
/// response itself.
final Expando<Future<void>> _hijacks = Expando('angel3_shelf hijack');

/// Records [done] as the end of the hijack of [request].
void setHijack(shelf.Request request, Future<void> done) =>
    _hijacks[request] = done;

/// Completes once the hijack of [request], or of a request changed from it,
/// is done; at once if it was not hijacked.
Future<void> hijackOf(shelf.Request request) {
  // canHijack is false once hijack has been called, before it has run.
  if (request.canHijack) return Future.value();
  return _hijacks[request] ?? Future.value();
}
