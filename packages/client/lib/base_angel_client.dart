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

Map<String, String> _buildQuery(Map<String, dynamic>? params) {
  return params?.map((k, v) => MapEntry(k, v.toString())) ?? {};
}

bool _invalid(Response response) =>
    response.statusCode < 200 || response.statusCode >= 300;

AngelHttpException failure(
  Response response, {
  error,
  String? message,
  StackTrace? stack,
}) {
  // A failure after a successful response (e.g. of the deserializer) is a 500,
  // not the response's 2xx.
  var statusCode = response.statusCode >= 200 && response.statusCode < 300
      ? 500
      : response.statusCode;
  dynamic v;

  try {
    v = json.decode(response.body);
  } catch (e, st) {
    return AngelHttpException(
      message:
          message ??
          'Angel backend did not return JSON - an error likely occurred.',
      statusCode: statusCode,
      error: error ?? e,
      stackTrace: stack ?? st,
    );
  }

  if (v is Map && (v['is_error'] == true || v['isError'] == true)) {
    return AngelHttpException.fromMap(v, fallbackStatusCode: statusCode)
      ..error = error
      ..stackTrace = stack;
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
      _onAuthenticated.add(r);
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
    Type? type,
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
/// [AngelHttpException], and also added to the stream of the method.
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
  Future close() async {
    await _onIndexed.close();
    await _onRead.close();
    await _onCreated.close();
    await _onModified.close();
    await _onUpdated.close();
    await _onRemoved.close();
  }

  BaseAngelService(this.client, this.app, baseUrl, {this.deserializer})
    : baseUrl = baseUrl is Uri ? baseUrl : Uri.parse(baseUrl.toString());

  Data? deserialize(dynamic x) {
    return deserializer != null ? deserializer!(x) : x as Data?;
  }

  /// Deserializes a single result, which must not be `null` unless [Data] is
  /// nullable.
  Data _deserializeOne(dynamic x) => deserialize(x) as Data;

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

  Uri _url(Map<String, dynamic>? params) {
    return baseUrl.replace(queryParameters: _buildQuery(params));
  }

  Uri _idUrl(Id id, Map<String, dynamic>? params) {
    return baseUrl.replace(
      path: _p.join(baseUrl.path, id.toString()),
      queryParameters: _buildQuery(params),
    );
  }

  /// Reads the result of [response] with [read], and adds it to [events].
  Future<T> _handle<T>(
    Response response,
    StreamController<T> events,
    T Function(dynamic body) read,
  ) async {
    if (_invalid(response)) {
      var e = failure(response);
      events.addError(e);
      throw e;
    }

    T result;

    try {
      result = read(json.decode(response.body));
    } catch (e, st) {
      _log.severe(
        'Could not read the response of ${response.request?.url}',
        e,
        st,
      );
      var f = failure(response, error: e, stack: st);
      events.addError(f, st);
      throw f;
    }

    events.add(result);
    return result;
  }

  @override
  Future<List<Data>> index([Map<String, dynamic>? params]) async {
    var response = await app.sendUnstreamed('GET', _url(params), _readHeaders);
    return _handle(
      response,
      _onIndexed,
      (v) => [for (var x in v as List) ?deserialize(x)],
    );
  }

  @override
  Future<Data> read(id, [Map<String, dynamic>? params]) async {
    var response = await app.sendUnstreamed(
      'GET',
      _idUrl(id, params),
      _readHeaders,
    );
    return _handle(response, _onRead, _deserializeOne);
  }

  @override
  Future<Data> create(data, [Map<String, dynamic>? params]) async {
    var response = await app.sendUnstreamed(
      'POST',
      _url(params),
      _writeHeaders,
      makeBody(data),
    );
    return _handle(response, _onCreated, _deserializeOne);
  }

  @override
  Future<Data> modify(id, data, [Map<String, dynamic>? params]) async {
    var response = await app.sendUnstreamed(
      'PATCH',
      _idUrl(id, params),
      _writeHeaders,
      makeBody(data),
    );
    return _handle(response, _onModified, _deserializeOne);
  }

  @override
  Future<Data> update(id, data, [Map<String, dynamic>? params]) async {
    var response = await app.sendUnstreamed(
      'POST',
      _idUrl(id, params),
      _writeHeaders,
      makeBody(data),
    );
    return _handle(response, _onUpdated, _deserializeOne);
  }

  @override
  Future<Data> remove(id, [Map<String, dynamic>? params]) async {
    var response = await app.sendUnstreamed(
      'DELETE',
      _idUrl(id, params),
      _readHeaders,
    );
    return _handle(response, _onRemoved, _deserializeOne);
  }
}
