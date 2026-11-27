import 'dart:async';

import 'package:angel3_route/angel3_route.dart';

import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'server.dart';

/// A handler that runs around the handlers after it, of a route's pipeline:
/// [next] runs them, and completes when they have, or fails with the error
/// one of them throws, so that code after it runs after them, as of a
/// `try`/`finally`.
///
/// It is made a [RequestHandler] by [around].
typedef AroundHandler = FutureOr<void> Function(
  RequestContext<dynamic> req,
  ResponseContext<dynamic> res,
  Future<void> Function() next,
);

final Expando<AroundHandler> _arounds = Expando('around');

/// Whether [around] has made a handler, so that a pipeline of none need not
/// look for one.
bool _anyAround = false;

/// [handler] as a [RequestHandler] of a pipeline, as of `app.fallback`,
/// `app.chain` or a route's middleware, that runs around the handlers after
/// it (issue 174):
///
/// ```dart
/// app.fallback(around((req, res, next) async {
///   var watch = Stopwatch()..start();
///   try {
///     await next();
///   } finally {
///     print('${req.path}: ${watch.elapsedMilliseconds} ms');
///   }
/// }));
/// ```
///
/// * [AroundHandler]'s `next` runs the rest of the pipeline: the handlers
///   after [handler] of its route, and of the routes after it. It completes
///   when they have, before the response is sent; it fails with an error one
///   of them throws, which [handler] may catch, as to roll back a
///   transaction, or rethrow to the app's error handler.
/// * The response is sent once the pipeline, [handler] with it, completes,
///   so [handler] must not wait for `res.done`, which would never complete:
///   to run code once the response is sent, as to time it, use
///   `res.done.then(...)`.
/// * An error of the rest is [handler]'s once `next` fails with it: if
///   [handler] then completes without an error, it has answered it, and the
///   pipeline stops after it. If [handler] throws, its error is the
///   request's, for the app's error handler.
/// * If [handler] does not call `next`, the pipeline stops after it, as of a
///   handler that returns `false`: it answers the request itself. `next` may
///   be called once, while [handler] runs; if it is not awaited, the
///   pipeline still waits for it, and an error of the rest after [handler]
///   completes is the request's.
/// * To rewrite the body that the handlers after it write, call
///   `res.useBuffer()` before `next`: an unbuffered response may have sent
///   its headers and body when `next` completes. A handler that closes the
///   response, as one that returns a value to serialize, locks its buffer:
///   rewrite that body in a finalizer of [Angel.responseFinalizers], which
///   runs before it is locked.
/// * In [chain], `next` runs the rest of the chain. Run anywhere else, as of
///   `app.executeHandler`, `next` runs nothing, and the handler is as one
///   that returns whether it called `next`.
RequestHandler around(AroundHandler handler) {
  Future<bool> run(RequestContext req, ResponseContext res) async {
    var called = false;
    await handler(req, res, () async {
      if (called) throw StateError('next() was called more than once.');
      called = true;
    });
    return called;
  }

  _anyAround = true;
  _arounds[run] = handler;
  return run;
}

/// Runs [handlers] from where they are, as the handlers of a route's
/// pipeline are, of [app]: each that returns `true` is followed by the next.
/// An [around] handler is given the rest as its `next`. Whether all of them
/// returned `true`. If [whileOpen], as of [chain], it stops, as `false`,
/// before a handler of a response that is closed.
Future<bool> runHandlers(
  Iterator<RequestHandler> handlers,
  RequestContext req,
  ResponseContext res,
  Angel app, {
  bool whileOpen = false,
}) async {
  while (handlers.moveNext()) {
    if (whileOpen && !res.isOpen) return false;
    var handler = handlers.current;
    if (_anyAround) {
      var wrap = _arounds[handler];
      if (wrap != null) {
        return _runAround(wrap, handlers, req, res, app, whileOpen);
      }
    }
    if (await app.executeHandler(handler, req, res) != true) return false;
  }
  return true;
}

Future<bool> _runAround(
  AroundHandler wrap,
  Iterator<RequestHandler> handlers,
  RequestContext req,
  ResponseContext res,
  Angel app,
  bool whileOpen,
) async {
  Future<bool>? rest;
  // Whether the rest has completed, and how: `null` while it runs.
  bool? completed;
  var failed = false;
  var finished = false;
  try {
    await wrap(req, res, () {
      if (finished) {
        throw StateError('next() was called after its handler completed.');
      }
      if (rest != null) throw StateError('next() was called more than once.');
      var running = rest = runHandlers(
        handlers,
        req,
        res,
        app,
        whileOpen: whileOpen,
      );
      running.then(
        (result) => completed = result,
        onError: (Object _) {
          failed = true;
          return completed = false;
        },
      );
      return running;
    });
  } catch (_) {
    // The handler's error is the request's; that of a `next` it did not
    // wait for is not left unhandled.
    rest?.ignore();
    rethrow;
  } finally {
    finished = true;
  }
  var running = rest;
  if (running == null) return false;
  // A rest that failed while the handler ran is the handler's to answer, as
  // it may have caught its error: the pipeline stops after it.
  if (failed) return false;
  // Of a `next` that was not awaited, the rest is waited for, and its error
  // is the request's.
  return completed ?? await running;
}

/// The handlers of the routes of [pipeline], one after another.
class PipelineHandlers implements Iterator<RequestHandler> {
  final Iterator<RoutingResult<RequestHandler>> _routes;
  Iterator<RequestHandler>? _handlers;

  PipelineHandlers(MiddlewarePipelineIterator<RequestHandler> pipeline)
    : _routes = pipeline;

  @override
  RequestHandler get current => _handlers!.current;

  @override
  bool moveNext() {
    while (true) {
      if (_handlers?.moveNext() == true) return true;
      if (!_routes.moveNext()) return false;
      _handlers = _routes.current.handlers.iterator;
    }
  }
}
