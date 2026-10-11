import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'body_sink.dart';
import 'connection_info.dart';
import 'headers.dart';
import 'lockable_headers.dart';

class MockHttpResponse extends Stream<List<int>> implements HttpResponse {
  late final MockBodySink _body;
  final LockableMockHttpHeaders _headers = LockableMockHttpHeaders();

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
    int contentLength = -1,
    this.deadline,
    required this._encoding,
    required this.persistentConnection,
    bool? bufferOutput,
  }) {
    _body = MockBodySink(
      'MockHttpResponse',
      _headers,
      () => encoding,
      copy: copyBuffer,
      bufferOutput: bufferOutput != false,
    );
    _headers.contentLength = contentLength;
  }

  @override
  bool get bufferOutput => _body.bufferOutput;

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

  /// The encoding kept from the first write, as in dart:io; before that, the
  /// charset in the `content-type` header, or else the encoding given to the
  /// constructor or set here.
  @override
  Encoding get encoding =>
      _body.writeEncoding ?? charsetEncoding(headers) ?? _encoding;

  @override
  set encoding(Encoding value) => _encoding = value;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future get done => _body.done;

  @override
  void add(List<int> data) => _body.add(data);

  @override
  void addError(error, [StackTrace? stackTrace]) =>
      _body.addError(error, stackTrace);

  /// Completes with the first error from [stream], which then stops adding.
  @override
  Future addStream(Stream<List<int>> stream) => _body.addStream(stream);

  /// Can be called more than once; later calls return [done].
  @override
  Future close() => _body.close();

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    throw UnsupportedError('MockHttpResponses have no socket to detach.');
  }

  @override
  Future flush() => _body.flush();

  @override
  Future redirect(
    Uri location, {
    int status = HttpStatus.movedTemporarily,
  }) async {
    statusCode = status;
  }

  /// Writes [obj] with [encoding], as it was at the first write.
  @override
  void write(Object? obj) => _body.write(obj);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _body.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _body.writeCharCode(charCode);

  @override
  void writeln([Object? obj = '']) => _body.writeln(obj);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _body.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError == true,
  );
}
