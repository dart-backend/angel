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

class MockHttpRequest
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

  // @override
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
  Future<bool> any(bool Function(Uint8List element) test) {
    return _body.stream.any((List<int> e) {
      return test(Uint8List.fromList(e));
    });
  }

  @override
  Stream<Uint8List> asBroadcastStream({
    void Function(StreamSubscription<Uint8List> subscription)? onListen,
    void Function(StreamSubscription<Uint8List> subscription)? onCancel,
  }) {
    return _body.stream.asBroadcastStream(
      onListen: onListen,
      onCancel: onCancel,
    );
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(Uint8List event) convert) =>
      _body.stream.asyncExpand(convert);

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Uint8List event) convert) =>
      _body.stream.asyncMap(convert);

  @override
  Future<bool> contains(Object? needle) => _body.stream.contains(needle);

  @override
  Stream<Uint8List> distinct([
    bool Function(Uint8List previous, Uint8List next)? equals,
  ]) => _body.stream.distinct(equals);

  @override
  Future<E> drain<E>([E? futureValue]) => _body.stream.drain(futureValue);

  @override
  Future<Uint8List> elementAt(int index) => _body.stream.elementAt(index);

  @override
  Future<bool> every(bool Function(Uint8List element) test) =>
      _body.stream.every(test);

  @override
  Stream<S> expand<S>(Iterable<S> Function(Uint8List value) convert) =>
      _body.stream.expand(convert);

  @override
  Future<Uint8List> get first => _body.stream.first;

  @override
  Future<Uint8List> firstWhere(
    bool Function(Uint8List element) test, {
    List<int> Function()? orElse,
  }) => _body.stream.firstWhere(test, orElse: _orElse(orElse));

  @override
  Future<S> fold<S>(
    S initialValue,
    S Function(S previous, Uint8List element) combine,
  ) => _body.stream.fold(initialValue, combine);

  @override
  Future forEach(void Function(Uint8List element) action) =>
      _body.stream.forEach(action);

  @override
  Stream<Uint8List> handleError(
    Function onError, {
    bool Function(Object?)? test,
  }) => _body.stream.handleError(onError, test: test);

  @override
  bool get isBroadcast => _body.stream.isBroadcast;

  @override
  Future<bool> get isEmpty => _body.stream.isEmpty;

  @override
  Future<String> join([String separator = '']) => _body.stream.join(separator);

  @override
  Future<Uint8List> get last => _body.stream.last;

  @override
  Future<Uint8List> lastWhere(
    bool Function(Uint8List element) test, {
    List<int> Function()? orElse,
  }) => _body.stream.lastWhere(test, orElse: _orElse(orElse));

  @override
  Future<int> get length => _body.stream.length;

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

  @override
  Stream<S> map<S>(S Function(Uint8List event) convert) =>
      _body.stream.map(convert);

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) =>
      _body.stream.cast<List<int>>().pipe(streamConsumer);

  @override
  Future<Uint8List> reduce(
    List<int> Function(Uint8List previous, Uint8List element) combine,
  ) {
    return _body.stream.reduce((Uint8List previous, Uint8List element) {
      return Uint8List.fromList(combine(previous, element));
    });
  }

  @override
  Future<Uint8List> get single => _body.stream.single;

  @override
  Future<Uint8List> singleWhere(
    bool Function(Uint8List element) test, {
    List<int> Function()? orElse,
  }) => _body.stream.singleWhere(test, orElse: _orElse(orElse));

  // Without orElse, no match is a StateError, as on any stream.
  static Uint8List Function()? _orElse(List<int> Function()? orElse) =>
      orElse == null ? null : () => Uint8List.fromList(orElse());

  @override
  Stream<Uint8List> skip(int count) => _body.stream.skip(count);

  @override
  Stream<Uint8List> skipWhile(bool Function(Uint8List element) test) =>
      _body.stream.skipWhile(test);

  @override
  Stream<Uint8List> take(int count) => _body.stream.take(count);

  @override
  Stream<Uint8List> takeWhile(bool Function(Uint8List element) test) =>
      _body.stream.takeWhile(test);

  @override
  Stream<Uint8List> timeout(
    Duration timeLimit, {
    void Function(EventSink<Uint8List> sink)? onTimeout,
  }) => _body.stream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<Uint8List>> toList() => _body.stream.toList();

  @override
  Future<Set<Uint8List>> toSet() => _body.stream.toSet();

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      _body.stream.cast<List<int>>().transform(streamTransformer);

  @override
  Stream<Uint8List> where(bool Function(Uint8List event) test) =>
      _body.stream.where(test);

  @override
  Stream<R> cast<R>() => Stream.castFrom<List<int>, R>(this);
}
