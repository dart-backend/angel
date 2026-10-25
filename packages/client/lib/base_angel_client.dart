import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

import 'angel3_client.dart';

const Map<String, String> _readHeaders = {'Accept': 'application/json'};
const Map<String, String> _writeHeaders = {
  'Accept': 'application/json',
  'Content-Type': 'application/json',
};

/// Adds [params] to the query of [url], keeping the query it has as it is, so
/// that a URL without params does not end in `?`. An [Iterable] param is sent
/// as one param per value, and a `null` param or value as `null`.
///
/// An empty [Iterable] cannot be sent, and leaving it out would drop a filter
/// and widen the query, so it throws an [ArgumentError].
///
/// The params are appended, not merged, so a param with the name of a param of
/// [url] is sent twice: `?key=x` with `{'key': 'y'}` is `?key=x&key=y`.
Uri _withQuery(Uri url, Map<String, dynamic>? params) {
  if (params == null || params.isEmpty) return url;
  var query = Uri(
    queryParameters: {
      for (var MapEntry(:key, :value) in params.entries)
        key: value is Iterable
            ? (value.isEmpty
                  ? throw ArgumentError.value(
                      params,
                      'params',
                      'the list "$key" is empty, and cannot be sent',
                    )
                  : [for (var v in value) '$v'])
            : '$value',
    },
  ).query;
  return url.replace(query: url.query.isEmpty ? query : '${url.query}&$query');
}

bool _invalid(Response response) =>
    response.statusCode < 200 || response.statusCode >= 300;

AngelHttpException failure(
  Response response, {
  error,
  String? message,
  StackTrace? stack,
}) {
  dynamic body;

  try {
    body = json.decode(response.body);
  } catch (_) {
    body = _notJson;
  }

  return _failure(response, body, error: error, message: message, stack: stack);
}

/// Stands for a body that is not JSON.
const _notJson = Object();

/// Returns the [AngelHttpException] for [response], whose decoded body is
/// [body], or [_notJson].
AngelHttpException _failure(
  Response response,
  dynamic body, {
  error,
  String? message,
  StackTrace? stack,
}) {
  // A failure after a successful response (e.g. of the deserializer) is a 500,
  // not the response's 2xx.
  var statusCode = _invalid(response) ? response.statusCode : 500;

  if (identical(body, _notJson)) {
    return AngelHttpException(
      message:
          message ??
          'Angel backend did not return JSON - an error likely occurred.',
      statusCode: statusCode,
      error: error,
      stackTrace: stack,
    );
  }

  if (body is Map && (body['is_error'] == true || body['isError'] == true)) {
    // fromMap prefers the status code of the body, but the status of the
    // response is the one the request failed with.
    var data = {...body}
      ..remove('status_code')
      ..remove('statusCode');
    var e = AngelHttpException.fromMap(data, fallbackStatusCode: statusCode)
      ..error = error
      ..stackTrace = stack;
    // The server's own message explains the error better than the failure
    // to read it.
    if (message != null && body['message'] == null) e.message = message;
    return e;
  }

  return AngelHttpException(
    message:
        message ?? 'Unhandled exception while connecting to Angel backend.',
    statusCode: statusCode,
    error: error,
    stackTrace: stack,
  );
}

abstract class BaseAngelClient extends Angel {
  final _log = Logger('BaseAngelClient');
  final StreamController<AngelAuthResult> _onAuthenticated =
      StreamController<AngelAuthResult>.broadcast();
  final List<Service> _services = [];
  final BaseClient client;

  final Context _p = Context(style: Style.url);

  @override
  Stream<AngelAuthResult> get onAuthenticated => _onAuthenticated.stream;

  BaseAngelClient(this.client, baseUrl) : super(baseUrl);

  @override
  Future<AngelAuthResult> authenticate({
    String? type,
    credentials,
    String authEndpoint = '/auth',
  }) async {
    type ??= 'token';

    var segments = baseUrl.pathSegments
        .followedBy(_p.split(authEndpoint))
        .followedBy([type]);

    //var p1 = p.joinAll(segments).replaceAll('\\', '/');

    var url = baseUrl.replace(path: _p.joinAll(segments));
    Response response;

    if (credentials != null) {
      response = await post(
        url,
        body: json.encode(credentials),
        headers: _writeHeaders,
      );
    } else {
      response = await post(url, headers: _writeHeaders);
    }

    if (_invalid(response)) {
      throw failure(response);
    }

    try {
      //var v = json.decode(response.body);
      _log.info(response.headers);

      var v = jsonDecode(response.body);

      if (v is! Map || !v.containsKey('data') || !v.containsKey('token')) {
        throw AngelHttpException.notAuthenticated(
          message: "Auth endpoint '$url' did not return a proper response.",
        );
      }

      var r = AngelAuthResult.fromMap(v);
      if (!_onAuthenticated.isClosed) _onAuthenticated.add(r);
      return r;
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      _log.severe(st);
      throw failure(response, error: e, stack: st);
    }
  }

  @override
  Future<void> close() async {
    client.close();
    await _onAuthenticated.close();
    await Future.wait(_services.map((s) => s.close())).then((_) {
      _services.clear();
    });
  }

  @override
  Future<void> logout() async {
    authToken = null;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (authToken?.isNotEmpty == true) {
      request.headers['authorization'] ??= 'Bearer $authToken';
    }
    return client.send(request);
  }

  /// Sends a non-streaming [Request] and returns a non-streaming [Response].
  Future<Response> sendUnstreamed(
    String method,
    url,
    Map<String, String>? headers, [
    body,
    Encoding? encoding,
  ]) async {
    var request = Request(method, url is Uri ? url : Uri.parse(url.toString()));

    if (headers != null) request.headers.addAll(headers);

    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = List<int>.from(body);
      } else if (body is Map<String, dynamic>) {
        request.bodyFields = body.map(
          (k, v) => MapEntry(k, v is String ? v : v.toString()),
        );
      } else {
        _log.severe('Body is not a String, List<int>, or Map<String, String>');
        throw ArgumentError.value(
          body,
          'body',
          'must be a String, List<int>, or Map<String, String>.',
        );
      }
    }

    return Response.fromStream(await send(request));
  }

  @override
  Service<Id, Data> service<Id, Data>(
    String path, {
    AngelDeserializer<Data>? deserializer,
  }) {
    var url = baseUrl.replace(path: _p.join(baseUrl.path, path));
    var s = BaseAngelService<Id, Data>(
      client,
      this,
      url,
      deserializer: deserializer,
    );
    _services.add(s);
    return s;
  }

  Uri _join(dynamic url) {
    var u = url is Uri ? url : Uri.parse(url.toString());
    if (u.hasScheme || u.hasAuthority) return u;
    return u.replace(path: _p.join(baseUrl.path, u.path));
  }

  //@override
  //Future<Response> delete(url, {Map<String, String> headers}) async {
  //  return sendUnstreamed('DELETE', _join(url), headers);
  //}

  @override
  Future<Response> get(url, {Map<String, String>? headers}) async {
    return sendUnstreamed('GET', _join(url), headers);
  }

  @override
  Future<Response> head(url, {Map<String, String>? headers}) async {
    return sendUnstreamed('HEAD', _join(url), headers);
  }

  @override
  Future<Response> patch(
    url, {
    body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) async {
    return sendUnstreamed('PATCH', _join(url), headers, body, encoding);
  }

  @override
  Future<Response> post(
    url, {
    body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) async {
    return sendUnstreamed('POST', _join(url), headers, body, encoding);
  }

  @override
  Future<Response> put(
    url, {
    body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) async {
    return sendUnstreamed('PUT', _join(url), headers, body, encoding);
  }
}

/// Queries a service over REST.
///
/// An error response, or one that cannot be read, is thrown as an
/// [AngelHttpException], and also added to the stream of the method, unless
/// the service is closed. Data that cannot be encoded is thrown as an
/// [ArgumentError], and a failure to send the request, such as a
/// `ClientException`, as it is; neither is added to the stream.
class BaseAngelService<Id, Data> extends Service<Id, Data> {
  final _log = Logger('BaseAngelService');

  @override
  final BaseAngelClient app;
  final Uri baseUrl;
  final BaseClient client;
  final AngelDeserializer<Data>? deserializer;

  final Context _p = Context(style: Style.url);

  final StreamController<List<Data>> _onIndexed = StreamController.broadcast();
  final StreamController<Data> _onRead = StreamController.broadcast(),
      _onCreated = StreamController.broadcast(),
      _onModified = StreamController.broadcast(),
      _onUpdated = StreamController.broadcast(),
      _onRemoved = StreamController.broadcast();

  @override
  Stream<List<Data>> get onIndexed => _onIndexed.stream;

  @override
  Stream<Data> get onRead => _onRead.stream;

  @override
  Stream<Data> get onCreated => _onCreated.stream;

  @override
  Stream<Data> get onModified => _onModified.stream;

  @override
  Stream<Data> get onUpdated => _onUpdated.stream;

  @override
  Stream<Data> get onRemoved => _onRemoved.stream;

  @override
  Future close() => Future.wait([
    _onIndexed.close(),
    _onRead.close(),
    _onCreated.close(),
    _onModified.close(),
    _onUpdated.close(),
    _onRemoved.close(),
  ]);

  BaseAngelService(this.client, this.app, baseUrl, {this.deserializer})
    : baseUrl = baseUrl is Uri ? baseUrl : Uri.parse(baseUrl.toString());

  Data? deserialize(dynamic x) {
    if (deserializer != null) return deserializer!(x);
    if (x is Data?) return x;
    throw FormatException(
      'The server returned a ${x.runtimeType}, not a $Data. '
      'Pass a deserializer to service() to turn the JSON into a $Data.',
    );
  }

  /// Deserializes a single result, which must not be `null` unless [Data] is
  /// nullable.
  Data _deserializeOne(dynamic x) {
    var data = deserialize(x);
    if (data is Data) return data;
    throw FormatException(
      deserializer == null
          ? 'The server returned null, not a $Data.'
          : 'The deserializer returned null, not a $Data.',
    );
  }

  String makeBody(dynamic x) {
    //return json.encode(x);
    return jsonEncode(x);
  }

  Future<StreamedResponse> send(BaseRequest request) {
    if (app.authToken != null && app.authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${app.authToken}';
    }

    return client.send(request);
  }

  Uri _url(Map<String, dynamic>? params) => _withQuery(baseUrl, params);

  /// The URL of [id], encoded as one path segment, so that an id such as
  /// `a/b` or `/admin` cannot leave the path of the service.
  ///
  /// An empty id would be the URL of the service itself, and `.` or `..` would
  /// be resolved away even when encoded, so they throw an [ArgumentError].
  Uri _idUrl(Id id, Map<String, dynamic>? params) {
    var segment = id.toString();
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw ArgumentError.value(id, 'id', 'cannot be a path segment');
    }
    return _withQuery(
      baseUrl.replace(
        path: _p.join(baseUrl.path, Uri.encodeComponent(segment)),
      ),
      params,
    );
  }

  void _emit<T>(StreamController<T> events, T value) {
    if (!events.isClosed) events.add(value);
  }

  void _emitError(StreamController events, Object error, StackTrace? stack) {
    if (!events.isClosed) events.addError(error, stack);
  }

  /// Encodes [data] with [makeBody], throwing an [ArgumentError] if it cannot
  /// be encoded as JSON, such as an object without a `toJson()`. An error
  /// thrown by a `toJson()`, and any other error, is thrown as it is.
  String _encode(dynamic data) {
    try {
      return makeBody(data);
    } on JsonUnsupportedObjectError catch (e, st) {
      // A value that a toJson() returns and that cannot be encoded is the
      // cause of the error of the object whose toJson() it is.
      var inner = e;
      while (inner.cause is JsonUnsupportedObjectError) {
        inner = inner.cause as JsonUnsupportedObjectError;
      }
      var cause = inner.cause;
      // jsonEncode reports a missing toJson() as a NoSuchMethodError.
      Error.throwWithStackTrace(
        cause != null && cause is! NoSuchMethodError
            ? cause
            : ArgumentError.value(
                data,
                'data',
                'cannot be encoded as JSON: $inner',
              ),
        st,
      );
    }
  }

  /// Sends a request, with [body], from [_encode], as its JSON body, and reads
  /// its response with [_handle].
  ///
  /// Errors from sending the request, like those from encoding the body, are
  /// only thrown, not added to [events], since they are not events of the
  /// service.
  Future<T> _request<T>(
    String method,
    Uri url,
    StreamController<T> events,
    T Function(dynamic body) read, [
    String? body,
  ]) async {
    var response = await app.sendUnstreamed(
      method,
      url,
      body == null ? _readHeaders : _writeHeaders,
      body,
    );
    return _handle(response, events, read);
  }

  /// Reads the result of [response] with [read], and adds it to [events].
  Future<T> _handle<T>(
    Response response,
    StreamController<T> events,
    T Function(dynamic body) read,
  ) async {
    if (_invalid(response)) {
      var e = failure(response, stack: StackTrace.current);
      _emitError(events, e, e.stackTrace);
      throw e;
    }

    dynamic body;
    T result;

    try {
      body = json.decode(response.body);
    } catch (e, st) {
      throw _readFailure(response, _notJson, events, e, st);
    }

    try {
      result = read(body);
    } catch (e, st) {
      throw _readFailure(
        response,
        body,
        events,
        e,
        st,
        e is FormatException && e.message.isNotEmpty
            ? e.message
            : 'Could not read the response: $e',
      );
    }

    _emit(events, result);
    return result;
  }

  /// Logs [error], which happened while reading [response], whose decoded body
  /// is [body], and returns it as an [AngelHttpException], also added to
  /// [events].
  AngelHttpException _readFailure(
    Response response,
    dynamic body,
    StreamController events,
    Object error,
    StackTrace stack, [
    String? message,
  ]) {
    _log.severe(
      'Could not read the response of ${response.request?.url}',
      error,
      stack,
    );
    var f = _failure(
      response,
      body,
      error: error,
      message: message,
      stack: stack,
    );
    _emitError(events, f, stack);
    return f;
  }

  @override
  Future<List<Data>> index([Map<String, dynamic>? params]) async => _request(
    'GET',
    _url(params),
    _onIndexed,
    (v) => [for (var x in v as List) ?deserialize(x)],
  );

  @override
  Future<Data> read(id, [Map<String, dynamic>? params]) async =>
      _request('GET', _idUrl(id, params), _onRead, _deserializeOne);

  @override
  Future<Data> create(data, [Map<String, dynamic>? params]) async => _request(
    'POST',
    _url(params),
    _onCreated,
    _deserializeOne,
    _encode(data),
  );

  @override
  Future<Data> modify(id, data, [Map<String, dynamic>? params]) async =>
      _request(
        'PATCH',
        _idUrl(id, params),
        _onModified,
        _deserializeOne,
        _encode(data),
      );

  @override
  Future<Data> update(id, data, [Map<String, dynamic>? params]) async =>
      _request(
        'POST',
        _idUrl(id, params),
        _onUpdated,
        _deserializeOne,
        _encode(data),
      );

  @override
  Future<Data> remove(id, [Map<String, dynamic>? params]) async =>
      _request('DELETE', _idUrl(id, params), _onRemoved, _deserializeOne);
}
