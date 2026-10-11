import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'body_sink.dart';
import 'connection_info.dart';
import 'headers.dart';
import 'lockable_headers.dart';
import 'response.dart';
import 'session.dart';

class MockHttpRequest extends Stream<Uint8List>
    implements HttpRequest, StreamSink<List<int>>, StringSink {
  late final MockBodySink _body;
  final LockableMockHttpHeaders _headers = LockableMockHttpHeaders();
  Uri? _requestedUri;
  late MockHttpSession _session;

  @override
  final List<Cookie> cookies = [];

  @override
  HttpConnectionInfo connectionInfo = MockHttpConnectionInfo(
    remoteAddress: InternetAddress.loopbackIPv4,
  );

  @override
  MockHttpResponse response = MockHttpResponse(
    encoding: utf8,
    persistentConnection: false,
    reasonPhrase: '',
    statusCode: 200,
  );

  @override
  HttpSession get session => _session;

  @override
  final String method;

  @override
  final Uri uri;

  @override
  bool persistentConnection = true;

  /// [copyBuffer] corresponds to `copy` on the [BytesBuilder] constructor.
  MockHttpRequest(
    this.method,
    this.uri, {
    bool copyBuffer = true,
    String? protocolVersion,
    String? sessionId,
    this.certificate,
    this.persistentConnection = true,
  }) {
    _body = MockBodySink(
      'MockHttpRequest',
      _headers,
      () => encoding,
      copy: copyBuffer,
    );
    _session = MockHttpSession(id: sessionId ?? 'mock-http-session');

    this.protocolVersion = protocolVersion ?? '1.1';
  }

  /// The `content-length` header, as in dart:io. [close] sets it to the
  /// number of bytes written, unless it was set already, nothing was
  /// written, or the headers ask for chunked encoding.
  @override
  int get contentLength => _headers.contentLength;

  @override
  HttpHeaders get headers => _headers;

  @override
  Uri get requestedUri {
    if (_requestedUri != null) {
      return _requestedUri!;
    } else {
      return _requestedUri = Uri(
        scheme: 'http',
        host: 'example.com',
        path: uri.path,
        query: uri.query,
      );
    }
  }

  set requestedUri(Uri value) {
    _requestedUri = value;
  }

  @override
  late String protocolVersion;

  @override
  X509Certificate? certificate;

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
  Future close() => _body.close(
    beforeClose: () {
      // As a client sends it: only for a body, and not with chunked encoding.
      if (_body.bytesWritten > 0 &&
          !_headers.chunkedTransferEncoding &&
          _headers.value(HttpHeaders.contentLengthHeader) == null) {
        setLockedContentLength(_headers, _body.bytesWritten);
      }
    },
  );

  @override
  Future get done => _body.done;

  Future flush() => _body.flush();

  /// The encoding [write] uses: the one it kept from the first write, or else
  /// the charset in the `content-type` header, or UTF-8 when it names none or
  /// one [Encoding] does not know.
  Encoding get encoding =>
      _body.writeEncoding ?? charsetEncoding(headers) ?? utf8;

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
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _body.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError == true,
    );
  }
}
