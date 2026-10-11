import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:charcode/ascii.dart';

import 'connection_info.dart';
import 'lockable_headers.dart';

class MockHttpResponse extends Stream<List<int>> implements HttpResponse {
  BytesBuilder _buf = BytesBuilder();
  bool _bufferOutput = true;
  final Completer _done = Completer();
  bool _isBound = false;
  final LockableMockHttpHeaders _headers = LockableMockHttpHeaders();
  final StreamController<List<int>> _stream = StreamController<List<int>>();

  @override
  final List<Cookie> cookies = [];

  @override
  HttpConnectionInfo connectionInfo = MockHttpConnectionInfo(
    remoteAddress: InternetAddress.anyIPv4,
  );

  /// [copyBuffer] corresponds to `copy` on the [BytesBuilder] constructor.
  MockHttpResponse({
    bool copyBuffer = true,
    required this.statusCode,
    required this.reasonPhrase,
    required int contentLength,
    this.deadline,
    required this._encoding,
    required this.persistentConnection,
    bool? bufferOutput,
  }) {
    _buf = BytesBuilder(copy: copyBuffer != false);
    _bufferOutput = bufferOutput != false;
    _headers.contentLength = contentLength;
  }

  @override
  bool get bufferOutput => _bufferOutput;

  @override
  set bufferOutput(bool value) {}

  // Backed by headers.contentLength, as in dart:io.
  @override
  int get contentLength => _headers.contentLength;

  @override
  set contentLength(int value) => _headers.contentLength = value;

  @override
  Duration? deadline;

  @override
  bool persistentConnection;

  @override
  String reasonPhrase;

  @override
  int statusCode;

  Encoding _encoding;

  /// The charset in the `content-type` header, as in dart:io, or else the
  /// encoding given to the constructor or set here.
  @override
  Encoding get encoding {
    var charset = headers.contentType?.charset;
    return (charset == null ? null : Encoding.getByName(charset)) ?? _encoding;
  }

  @override
  set encoding(Encoding value) => _encoding = value;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future get done => _done.future;

  // Like dart:io's IOSink: closed and bound sinks reject writes.
  void _checkWritable() {
    if (_isBound) {
      throw StateError('MockHttpResponse is bound to a stream.');
    } else if (_done.isCompleted) {
      throw StateError('Cannot add to closed MockHttpResponse.');
    }
  }

  @override
  void add(List<int> data) {
    _checkWritable();
    _add(data);
  }

  void _add(List<int> data) {
    _headers.lock();
    if (_bufferOutput == true) {
      _buf.add(data);
    } else {
      _stream.add(data);
    }
  }

  @override
  void addError(error, [StackTrace? stackTrace]) {
    _checkWritable();
    _stream.addError(error, stackTrace);
  }

  /// Completes with the first error from [stream], which then stops adding.
  @override
  Future addStream(Stream<List<int>> stream) {
    _checkWritable();
    var c = Completer();
    stream.listen(
      _add,
      onError: (Object error, StackTrace stackTrace) {
        _isBound = false;
        c.completeError(error, stackTrace);
      },
      onDone: () {
        _isBound = false;
        c.complete();
      },
      cancelOnError: true,
    );
    // Only once listen has not thrown, so a bad stream cannot leave it bound.
    _isBound = true;
    return c.future;
  }

  /// Can be called more than once; later calls return [done].
  @override
  Future close() {
    if (_isBound) throw StateError('MockHttpResponse is bound to a stream.');
    if (!_done.isCompleted) {
      _headers.lock();
      _stream.add(_buf.takeBytes());
      scheduleMicrotask(_stream.close);
      _done.complete();
    }
    return done;
  }

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    throw UnsupportedError('MockHttpResponses have no socket to detach.');
  }

  @override
  Future flush() {
    if (_isBound) throw StateError('MockHttpResponse is bound to a stream.');
    if (!_done.isCompleted) _stream.add(_buf.takeBytes());
    return Future.value();
  }

  @override
  Future redirect(
    Uri location, {
    int status = HttpStatus.movedTemporarily,
  }) async {
    statusCode = status;
  }

  /// Writes [obj] with [encoding].
  @override
  void write(Object? obj) {
    if (obj != null) add(encoding.encode(obj.toString()));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? obj = '']) {
    write(obj ?? '');
    add([$cr, $lf]);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError == true,
  );
}
