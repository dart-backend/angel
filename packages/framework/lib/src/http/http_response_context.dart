import 'dart:async';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data' show BytesBuilder;

import 'package:http_parser/http_parser.dart';

import '../core/core.dart';
import 'http_request_context.dart';

/// An implementation of [ResponseContext] that abstracts over an [HttpResponse].
class HttpResponseContext extends ResponseContext<HttpResponse> {
  /// The underlying [HttpResponse] under this instance.
  @override
  final HttpResponse rawResponse;

  LockableBytesBuilder? _buffer;

  final HttpRequestContext? _correspondingRequest;
  bool _isDetached = false, _isClosed = false, _streamInitialized = false;

  HttpResponseContext(
    this.rawResponse,
    Angel? app, [
    this._correspondingRequest,
  ]) {
    this.app = app;
  }

  @override
  HttpResponse detach() {
    _isDetached = true;
    return rawResponse;
  }

  @override
  RequestContext? get correspondingRequest {
    return _correspondingRequest;
  }

  @override
  bool get isOpen {
    return !_isClosed && !_isDetached;
  }

  @override
  bool get isBuffered => _buffer != null;

  @override
  BytesBuilder? get buffer => _buffer;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    rawResponse.addError(error, stackTrace);
    super.addError(error, stackTrace);
  }

  @override
  void useBuffer() {
    _buffer = LockableBytesBuilder();
  }

  @override
  set contentType(MediaType value) {
    super.contentType = value;
    if (!_streamInitialized) {
      rawResponse.headers.contentType = ContentType(
        value.type,
        value.subtype,
        parameters: value.parameters,
      );
    }
  }

  /// Compresses unbuffered output as one stream, created when output starts.
  ///
  /// A single chunked conversion is used for the whole response: encoding
  /// each write separately would emit several concatenated gzip members,
  /// which many clients do not decode past the first.
  Sink<List<int>>? _encoderSink;

  bool _openStream() {
    if (!_streamInitialized) {
      // If this is the first stream added to this response,
      // then add headers, status code, etc.
      var encoding = selectedEncoder;
      if (encoding != null) {
        // A Content-Length set beforehand (e.g. by streamFile) describes the
        // uncompressed size; sending it with a compressed body makes dart:io
        // fail the response. Send the body chunked instead.
        headers.remove('content-length');
        headers['content-encoding'] = encoding.name;
      }

      rawResponse
        ..statusCode = statusCode
        ..cookies.addAll(cookies);
      headers.forEach(rawResponse.headers.set);

      rawResponse.headers.date = DateTime.now();

      if (encoding != null) {
        rawResponse.contentLength = -1;
        _encoderSink = encoding.encoder.startChunkedConversion(
          _HttpResponseSink(rawResponse),
        );
      } else if (headers.containsKey('content-length')) {
        rawResponse.contentLength =
            int.tryParse(headers['content-length']!) ??
            rawResponse.contentLength;
      }

      rawResponse.headers.contentType = ContentType(
        contentType.type,
        contentType.subtype,
        charset: contentType.parameters['charset'],
        parameters: contentType.parameters,
      );

      return _streamInitialized = true;
    }

    return false;
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    if (_isClosed && isBuffered) throw ResponseContext.closed();
    _openStream();

    var sink = _encoderSink;
    if (sink == null) return rawResponse.addStream(stream);

    // Feed the shared encoder, flushing after each chunk so a slow client
    // applies backpressure instead of the whole stream being buffered.
    await for (var chunk in stream) {
      sink.add(chunk);
      await rawResponse.flush();
    }
  }

  @override
  void add(List<int> data) {
    if (_isClosed && isBuffered) {
      throw ResponseContext.closed();
    } else if (!isBuffered) {
      if (!_isClosed) {
        _openStream();
        var sink = _encoderSink;
        if (sink != null) {
          sink.add(data);
        } else {
          rawResponse.add(data);
        }
      }
    } else {
      buffer!.add(data);
    }
  }

  @override
  Future close() {
    if (!_isDetached) {
      if (!_isClosed) {
        if (!isBuffered) {
          try {
            _openStream();
            // Flushes the compression trailer, if any.
            _encoderSink?.close();
            // Observe the result: an unhandled failure here (e.g. the
            // connection dropped) would otherwise terminate the server.
            rawResponse.close().catchError((Object e, StackTrace st) {
              app?.logger.warning('Failed to send response', e, st);
            });
          } catch (_) {
            // This only seems to occur on `MockHttpRequest`, but
            // this try/catch prevents a crash.
          }
        } else {
          _buffer!.lock();
        }

        _isClosed = true;
      }

      super.close();
    }
    return Future.value();
  }
}

/// Writes encoder output straight to an [HttpResponse].
class _HttpResponseSink implements Sink<List<int>> {
  final HttpResponse response;

  _HttpResponseSink(this.response);

  @override
  void add(List<int> data) => response.add(data);

  @override
  void close() {}
}
