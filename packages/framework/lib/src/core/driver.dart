import 'dart:async';
import 'dart:convert';
import 'dart:io' show stderr, Cookie;
import 'package:angel3_http_exception/angel3_http_exception.dart';
import 'package:angel3_route/angel3_route.dart';
import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';
import 'core.dart';

/// Base driver class for Angel implementations.
///
/// Powers both AngelHttp and AngelHttp2.
abstract class Driver<
    Request,
    Response,
    Server extends Stream<Request>,
    RequestContextType extends RequestContext,
    ResponseContextType extends ResponseContext> {
  final Angel app;
  final bool useZone;
  bool _closed = false;
  late Server _server;

  // TODO: Ugly fix
  bool isServerInitialised = false;

  StreamSubscription<Request>? _sub;
  //final log = Logger('Driver');

  /// The function used to bind this instance to a server..
  final Future<Server> Function(dynamic, int) serverGenerator;

  Driver(this.app, this.serverGenerator, {this.useZone = true});

  /// The path at which this server is listening for requests.
  Uri get uri;

  /// The native server running this instance.
  Server? get server {
    // TODO: Ugly fix
    if (isServerInitialised) {
      return _server;
    } else {
      return null;
    }
  }

  Future<Server> generateServer(address, int port) =>
      serverGenerator(address, port);

  /// Starts, and returns the server.
  Future<Server> startServer([address, int port = 0]) {
    var host = address ?? '127.0.0.1';
    return generateServer(host, port).then((server) {
      _server = server;

      // TODO: Ugly fix
      isServerInitialised = true;

      return Future.wait(app.startupHooks.map(app.configure)).then((_) {
        app.optimizeForProduction();
        _sub = server.listen((request) {
          var stream = createResponseStreamFromRawRequest(request);
          stream.listen((response) {
            // TODO: To be revisited
            handleRawRequest(request, response);
          });
        });
        return Future.value(_server);
      });
    }).catchError((error) {
      app.logger?.severe('Failed to create server', error);
      throw ArgumentError('[Driver]Failed to create server');
    });
  }

  /// Shuts down the underlying server.
  Future<void> close() {
    if (_closed) {
      //return Future.value(_server);
      return Future.value();
    }
    _closed = true;

    _sub?.cancel();

    return app.close().then((_) =>
        Future.wait(app.shutdownHooks.map(app.configure))
            .then((_) => Future.value()));
    /*
    return app.close().then((_) =>
        Future.wait(app.shutdownHooks.map(app.configure))
            .then((_) => Future.value(_server)));
    */
  }

  Future<RequestContextType> createRequestContext(
      Request request, Response response);

  Future<ResponseContextType> createResponseContext(
      Request request, Response response,
      [RequestContextType? correspondingRequest]);

  void setHeader(Response response, String key, String value);

  void setContentLength(Response response, int length);

  void setChunkedEncoding(Response response, bool value);

  void setStatusCode(Response response, int value);

  void addCookies(Response response, Iterable<Cookie> cookies);

  void writeStringToResponse(Response response, String value);

  void writeToResponse(Response response, List<int> data);

  Future closeResponse(Response response);

  Stream<Response> createResponseStreamFromRawRequest(Request request);

  /// Handles a single request.
  Future handleRawRequest(Request request, Response response) {
    return createRequestContext(request, response).then((req) {
      return createResponseContext(request, response, req).then((res) {
        Future handle() {
          var path = req.path;
          if (path == '/') path = '';

          Tuple4<List, Map<String, dynamic>, ParseResult<RouteResult>,
              MiddlewarePipeline> resolveTuple() {
            var r = app.optimizedRouter;
            var resolved =
                r.resolveAbsolute(path, method: req.method, strip: false);
            var pipeline = MiddlewarePipeline<RequestHandler>(resolved);
            return Tuple4(
              pipeline.handlers,
              resolved.fold<Map<String, dynamic>>(
                  <String, dynamic>{}, (out, r) => out..addAll(r.allParams)),
              //(resolved.isEmpty ? null : resolved.first.parseResult),
              resolved.first.parseResult,
              pipeline,
            );
          }

          var cacheKey = req.method + path;
          var tuple = app.environment.isProduction
              ? app.handlerCache.putIfAbsent(cacheKey, resolveTuple)
              : resolveTuple();
          var line = tuple.item4 as MiddlewarePipeline<RequestHandler>;
          var it = MiddlewarePipelineIterator<RequestHandler>(line);

          req.params.addAll(tuple.item2);

          req.container
            ?..registerSingleton<RequestContext>(req)
            ..registerSingleton<ResponseContext>(res)
            ..registerSingleton<MiddlewarePipeline>(tuple.item4)
            ..registerSingleton<MiddlewarePipeline<RequestHandler>>(line)
            ..registerSingleton<MiddlewarePipelineIterator>(it)
            ..registerSingleton<MiddlewarePipelineIterator<RequestHandler>>(it)
            ..registerSingleton<ParseResult<RouteResult>?>(tuple.item3)
            ..registerSingleton<ParseResult?>(tuple.item3);

          if (!app.environment.isProduction && app.logger != null) {
            req.container?.registerSingleton<Stopwatch>(Stopwatch()..start());
          }

          return runPipeline(it, req, res, app)
              .then((_) => sendResponse(request, response, req, res));
        }

        if (useZone == false) {
          Future f;

          try {
            f = handle();
          } catch (e, st) {
            f = Future.error(e, st);
          }

          return f.catchError((e, StackTrace st) {
            if (e is FormatException) {
              throw AngelHttpException.badRequest(message: e.message)
                ..stackTrace = st;
            }
            throw AngelHttpException(e,
                stackTrace: st,
                statusCode: (e is AngelHttpException) ? e.statusCode : 500,
                message: e?.toString() ?? '500 Internal Server Error');
          }, test: (e) => e is AngelHttpException).catchError(
              (ee, StackTrace st) {
            //print(">>>> Framework error: $ee");
            //var t = (st).runtimeType;
            //print(">>>> StackTrace: $t");
            AngelHttpException e;
            if (ee is AngelHttpException) {
              e = ee;
            } else {
              e = AngelHttpException(ee,
                  stackTrace: st,
                  statusCode: 500,
                  message: ee?.toString() ?? '500 Internal Server Error');
            }

            if (app.logger != null) {
              var error = e.error ?? e;
              var trace = Trace.from(StackTrace.current).terse;
              app.logger?.severe(e.message, error, trace);
            }

            return handleAngelHttpException(e, st, req, res, request, response);
          });
        } else {
          var zoneSpec = ZoneSpecification(
            print: (self, parent, zone, line) {
              if (app.logger != null) {
                app.logger?.info(line);
              } else {
                parent.print(zone, line);
              }
            },
            handleUncaughtError: (self, parent, zone, error, stackTrace) {
              var trace = Trace.from(stackTrace).terse;

              // TODO: To be revisited
              Future(() {
                AngelHttpException e;

                if (error is FormatException) {
                  e = AngelHttpException.badRequest(message: error.message);
                } else if (error is AngelHttpException) {
                  e = error;
                } else {
                  e = AngelHttpException(error,
                      stackTrace: stackTrace, message: error.toString());
                }

                if (app.logger != null) {
                  app.logger?.severe(e.message, error, trace);
                }

                return handleAngelHttpException(
                    e, trace, req, res, request, response);
              }).catchError((e, StackTrace st) {
                var trace = Trace.from(st).terse;
                closeResponse(response);
                // Ideally, we won't be in a position where an absolutely fatal error occurs,
                // but if so, we'll need to log it.
                if (app.logger != null) {
                  app.logger!.severe(
                      'Fatal error occurred when processing $uri.', e, trace);
                } else {
                  stderr
                    ..writeln('Fatal error occurred when processing '
                        '${req.uri}:')
                    ..writeln(e)
                    ..writeln(trace);
                }
              });
            },
          );

          var zone = Zone.current.fork(specification: zoneSpec);
          req.container!.registerSingleton<Zone>(zone);
          req.container!.registerSingleton<ZoneSpecification>(zoneSpec);

          // If a synchronous error is thrown, it's not caught by `zone.run`,
          // so use a try/catch, and recover when need be.

          try {
            return zone.run(handle);
          } catch (e, st) {
            zone.handleUncaughtError(e, st);
            return Future.value();
          }
        }
      });
    });
  }

  /// Handles an [AngelHttpException].
  Future handleAngelHttpException(
      AngelHttpException e,
      StackTrace st,
      RequestContext? req,
      ResponseContext? res,
      Request request,
      Response response,
      {bool ignoreFinalizers = false}) {
    if (req == null || res == null) {
      try {
        app.logger?.severe('500 Internal Server Error', e, st);
        setStatusCode(response, 500);
        writeStringToResponse(response, '500 Internal Server Error');
        closeResponse(response);
      } catch (e) {
        app.logger?.severe('500 Internal Server Error', e);
      }
      return Future.value();
    }

    Future handleError;

    if (!res.isOpen) {
      handleError = Future.value();
    } else {
      res.statusCode = e.statusCode;
      handleError =
          Future.sync(() => app.errorHandler(e, req, res)).then((result) {
        return app.executeHandler(result, req, res).then((_) => res.close());
      });
    }

    return handleError.then((_) => sendResponse(request, response, req, res,
        ignoreFinalizers: ignoreFinalizers == true));
  }

  /// Sends a response.
  Future sendResponse(Request request, Response response, RequestContext req,
      ResponseContext res,
      {bool ignoreFinalizers = false}) {
    Future<void> _cleanup(_) {
      if (!app.environment.isProduction &&
          app.logger != null &&
          req.container!.has<Stopwatch>()) {
        var sw = req.container!.make<Stopwatch>();
        app.logger?.info(
            "${res.statusCode} ${req.method} ${req.uri} (${sw.elapsedMilliseconds} ms)");
      }
      return req.close();
    }

    if (!res.isBuffered) {
      //if (res.isOpen) {
      return res.close().then(_cleanup);
      //}
      //return Future.value();
    }

    var finalizers = ignoreFinalizers == true
        ? Future.value()
        : Future.forEach(app.responseFinalizers, (dynamic f) => f(req, res));

    return finalizers.then((_) {
      //if (res.isOpen) res.close();

      for (var key in res.headers.keys) {
        setHeader(response, key, res.headers[key] ?? '');
      }

      setContentLength(response, res.buffer?.length ?? 0);
      setChunkedEncoding(response, res.chunked ?? true);

      var outputBuffer = res.buffer?.toBytes() ?? <int>[];

      if (res.encoders.isNotEmpty) {
        var allowedEncodings = req.headers
            ?.value('accept-encoding')
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((str) {
          // Ignore quality specifications in accept-encoding
          // ex. gzip;q=0.8
          if (!str.contains(';')) return str;
          return str.split(';')[0];
        });

        if (allowedEncodings != null) {
          for (var encodingName in allowedEncodings) {
            var key = encodingName;

            Converter<List<int>, List<int>>? encoder;
            if (res.encoders.containsKey(encodingName)) {
              encoder = res.encoders[encodingName];
            } else if (encodingName == '*') {
              encoder = res.encoders[key = res.encoders.keys.first];
            }

            if (encoder != null) {
              setHeader(response, 'content-encoding', key);
              outputBuffer =
                  res.encoders[key]?.convert(outputBuffer) ?? <int>[];
              setContentLength(response, outputBuffer.length);
              break;
            }
          }
        }
      }

      setStatusCode(response, res.statusCode);
      addCookies(response, res.cookies);
      writeToResponse(response, outputBuffer);
      return closeResponse(response).then(_cleanup);
    });
  }

  /// Runs a [MiddlewarePipeline].
  static Future<void> runPipeline<RequestContextType extends RequestContext,
          ResponseContextType extends ResponseContext>(
      MiddlewarePipelineIterator<RequestHandler> it,
      RequestContextType req,
      ResponseContextType res,
      Angel app) async {
    var broken = false;
    while (it.moveNext()) {
      var current = it.current.handlers.iterator;

      while (!broken && current.moveNext()) {
        var result = await app.executeHandler(current.current, req, res);
        if (result != true) {
          broken = true;
          break;
        }
      }
    }
  }
}
