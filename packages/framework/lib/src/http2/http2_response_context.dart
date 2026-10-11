import 'dart:async';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:http2/transport.dart';
import 'package:meta/meta.dart';

import 'http2_request_context.dart';

class Http2ResponseContext extends ResponseContext<ServerTransportStream> {
  final ServerTransportStream stream;

  @override
  ServerTransportStream get rawResponse => stream;

  LockableBytesBuilder? _buffer;

  final Http2RequestContext? _req;

  bool _isDetached = false,
      _isClosed = false,
      _streamInitialized = false,
      _isPush = false;

  Uri? _targetUri;

  /// The method of a pushed request; see [push].
  String? _pushMethod;

  Http2ResponseContext(Angel? app, this.stream, this._req) {
    this.app = app;
    _targetUri = _req?.uri;
  }

  final List<Http2ResponseContext> _pushes = [];

  /// Returns `true` if an attempt to [push] a resource will succeed.
  ///
  /// See [ServerTransportStream].`push`.
  bool get canPush => stream.canPush;

  /// Returns a [List] of all resources that have [push]ed to the client.
  List<Http2ResponseContext> get pushes => List.unmodifiable(_pushes);

  @override
  ServerTransportStream detach() {
    _isDetached = true;
    return stream;
  }

  @override
  RequestContext? get correspondingRequest => _req;

  Uri? get targetUri => _targetUri;

  @override
  bool get isOpen {
    return !_isClosed && !_isDetached;
  }

  @override
  bool get isBuffered => _buffer != null;

  @override
  BytesBuilder? get buffer => _buffer;

  // @override
  // void addError(Object error, [StackTrace? stackTrace]) {
  //   super.addError(error, stackTrace);
  // }

  @override
  void useBuffer() {
    _buffer = LockableBytesBuilder();
  }

  /// Write headers, status, etc. to the underlying [stream].
  bool _openStream() {
    if (_streamInitialized) return false;
    validateHeaders();

    var headers = <Header>[Header.ascii(':status', statusCode.toString())];

    var encoding = selectedEncoder;
    if (encoding != null) {
      // A Content-Length set beforehand (e.g. by streamFile) describes the
      // uncompressed size, so it must not accompany a compressed body.
      this.headers.remove('content-length');
      this.headers['content-encoding'] = encoding.name;
      // A HEAD response has no body, so it gets no compressed framing.
      if (!_omitBody) {
        _encoderSink = encoding.encoder.startChunkedConversion(
          _StreamDataSink(stream),
        );
      }
    }

    // Add all normal headers
    for (var key in this.headers.keys) {
      headers.add(Header.ascii(key.toLowerCase(), this.headers[key]!));
    }

    // A pushed response belongs to the request that pushed it.
    if (!_isPush) addSessionCookie();

    // Send all cookies
    for (var cookie in cookies) {
      headers.add(Header.ascii('set-cookie', cookie.toString()));
    }

    stream.sendHeaders(headers);
    return _streamInitialized = true;
  }

  /// Adds the session ID cookie, if the request has a session and it has not
  /// been added yet. HTTP/2 here always runs over TLS, so the cookie is
  /// Secure; HttpOnly keeps it from page scripts.
  @internal
  void addSessionCookie() {
    var req = _req;
    if (req == null || !req.hasSession) return;
    if (cookies.any((c) => c.name == 'DARTSESSID')) return;
    cookies.add(
      Cookie('DARTSESSID', req.session!.id)
        ..secure = true
        ..httpOnly = true,
    );
  }

  /// Compresses unbuffered output as one stream (see `HttpResponseContext`).
  Sink<List<int>>? _encoderSink;

  /// Writes made while response finalizers run, sent once headers go out.
  final List<List<int>> _queued = [];
  Future<void>? _finalizing;
  Object? _finalizerError;
  StackTrace? _finalizerStackTrace;

  /// Pushed resources are not finalized; only the main response is.
  bool get _needsFinalizers => !_isPush && hasPendingFinalizers;

  /// Sends status and headers after running response finalizers (if any);
  /// see `HttpResponseContext`. On a finalizer failure nothing is sent.
  Future<void> _commit() {
    if (_streamInitialized) return Future.value();
    var running = _finalizing;
    if (running != null) return running;
    if (!_needsFinalizers) {
      _openStream();
      _flushQueued();
      return Future.value();
    }

    return _finalizing = runFinalizers().then(
      (_) {
        _finalizing = null;
        _openStream();
        _flushQueued();
      },
      onError: (Object e, StackTrace st) {
        _finalizing = null;
        _queued.clear();
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  /// Like [_commit], but rethrows a finalizer failure from an earlier [add].
  Future<void> _commitOrThrow() async {
    var error = _finalizerError;
    if (error != null) {
      _finalizerError = null;
      Error.throwWithStackTrace(error, _finalizerStackTrace!);
    }
    try {
      await _commit();
    } catch (_) {
      _finalizerError = null;
      rethrow;
    }
  }

  /// A `HEAD` response carries the headers of the `GET` response but no body
  /// (RFC 9110); unlike dart:io, package:http2 does not drop it for us.
  bool get _omitBody => (_isPush ? _pushMethod : _req?.method) == 'HEAD';

  void _write(List<int> data) {
    if (_omitBody) return;
    var sink = _encoderSink;
    if (sink != null) {
      sink.add(data);
    } else {
      stream.sendData(data);
    }
  }

  void _flushQueued() {
    for (var data in _queued) {
      _write(data);
    }
    _queued.clear();
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    if (!isOpen && isBuffered) throw ResponseContext.closed();
    // A buffered response is sent as a whole by the driver, so do not send
    // headers now; add() appends to the buffer.
    if (!isBuffered) await _commitOrThrow();
    await stream.forEach(add);
  }

  @override
  void add(List<int> data) {
    if (!isOpen && isBuffered) {
      throw ResponseContext.closed();
    } else if (!isBuffered) {
      if (_isClosed) return;

      if (_streamInitialized || _isPush) {
        _openStream();
        _write(data);
      } else if (_finalizing != null || _needsFinalizers) {
        // Headers wait for the finalizers; send this data after them.
        _queued.add(data);
        _commit().catchError((Object e, StackTrace st) {
          _finalizerError ??= e;
          _finalizerStackTrace ??= st;
        });
      } else {
        _openStream();
        _write(data);
      }
    } else {
      buffer!.add(data);
    }
  }

  @override
  Future close() async {
    if (!_isDetached && !_isClosed && !isBuffered) {
      // Finalizer failures propagate, leaving the response open for the
      // error handler.
      await _commitOrThrow();
      _openStream();
      _flushQueued();
      // Flushes the compression trailer, if any.
      _encoderSink?.close();
      await stream.outgoingMessages.close();
    }

    _isClosed = true;
    await super.close();
  }

  /// Pushes a resource to the client.
  Http2ResponseContext push(
    String path, {
    Map<String, String> headers = const {},
    String method = 'GET',
  }) {
    var targetUri = _req!.uri!.replace(path: path);

    var h = <Header>[
      Header.ascii(':authority', targetUri.authority),
      Header.ascii(':method', method),
      Header.ascii(':path', targetUri.path),
      Header.ascii(':scheme', targetUri.scheme),
    ];

    for (var key in headers.keys) {
      var value = headers[key]!;
      if (!ResponseContext.isValidHeaderName(key) ||
          !ResponseContext.isValidHeaderValue(value)) {
        throw ArgumentError.value(key, 'headers', 'Invalid push header');
      }
      h.add(Header.ascii(key.toLowerCase(), value));
    }

    var s = stream.push(h);
    var r = Http2ResponseContext(app, s, _req)
      .._isPush = true
      .._pushMethod = method
      .._targetUri = targetUri;
    _pushes.add(r);
    return r;
  }
}

/// Writes encoder output to an HTTP/2 stream as DATA frames.
class _StreamDataSink implements Sink<List<int>> {
  final ServerTransportStream stream;

  _StreamDataSink(this.stream);

  @override
  void add(List<int> data) => stream.sendData(data);

  @override
  void close() {}
}
