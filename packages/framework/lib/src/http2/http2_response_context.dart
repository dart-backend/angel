import 'dart:async';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:http2/transport.dart';

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
    if (_isPush || _streamInitialized) return false;

    var headers = <Header>[Header.ascii(':status', statusCode.toString())];

    var encoding = selectedEncoder;
    if (encoding != null) {
      // A Content-Length set beforehand (e.g. by streamFile) describes the
      // uncompressed size, so it must not accompany a compressed body.
      this.headers.remove('content-length');
      this.headers['content-encoding'] = encoding.name;
      _encoderSink = encoding.encoder.startChunkedConversion(
        _StreamDataSink(stream),
      );
    }

    // Add all normal headers
    for (var key in this.headers.keys) {
      headers.add(Header.ascii(key.toLowerCase(), this.headers[key]!));
    }

    // Persist session ID
    cookies.add(Cookie('DARTSESSID', _req!.session!.id));

    // Send all cookies
    for (var cookie in cookies) {
      headers.add(Header.ascii('set-cookie', cookie.toString()));
    }

    stream.sendHeaders(headers);
    return _streamInitialized = true;
  }

  /// Compresses unbuffered output as one stream (see `HttpResponseContext`).
  Sink<List<int>>? _encoderSink;

  @override
  Future addStream(Stream<List<int>> stream) async {
    if (!isOpen && isBuffered) throw ResponseContext.closed();
    _openStream();
    await stream.forEach(add);
  }

  @override
  void add(List<int> data) {
    if (!isOpen && isBuffered) {
      throw ResponseContext.closed();
    } else if (!isBuffered) {
      _openStream();

      if (!_isClosed) {
        var sink = _encoderSink;
        if (sink != null) {
          sink.add(data);
        } else {
          stream.sendData(data);
        }
      }
    } else {
      buffer!.add(data);
    }
  }

  @override
  Future close() async {
    if (!_isDetached && !_isClosed && !isBuffered) {
      _openStream();
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
      h.add(Header.ascii(key, headers[key]!));
    }

    var s = stream.push(h);
    var r = Http2ResponseContext(app, s, _req)
      .._isPush = true
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
