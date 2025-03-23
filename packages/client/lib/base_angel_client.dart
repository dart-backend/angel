import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';
import 'angel3_client.dart';

const Map<String, String> _readHeaders = {'Accept': 'application/json'};
const Map<String, String> _writeHeaders = {
  'Accept': 'application/json',
  'Content-Type': 'application/json'
};

Map<String, String> _buildQuery(Map<String, dynamic>? params) {
  return params?.map((k, v) => MapEntry(k, v.toString())) ?? {};
}

bool _invalid(Response response) =>
    response.statusCode < 200 || response.statusCode >= 300;

AngelHttpException failure(Response response,
    {error, String? message, StackTrace? stack}) {
  try {
    var v = json.decode(response.body);

    if (v is Map && (v['is_error'] == true) || v['isError'] == true) {
      return AngelHttpException.fromMap(v as Map);
    } else {
      return AngelHttpException(
          message: message ??
              'Unhandled exception while connecting to Angel backend.',
          statusCode: response.statusCode,
          stackTrace: stack);
    }
  } catch (e, st) {
    return AngelHttpException(
        message: message ??
            'Angel backend did not return JSON - an error likely occurred.',
        statusCode: response.statusCode,
        stackTrace: stack ?? st);
  }
}

abstract class BaseAngelClient extends Angel {
  final _log = Logger('BaseAngelClient');
  final StreamController<AngelAuthResult> _onAuthenticated =
      StreamController<AngelAuthResult>();
  final List<Service> _services = [];
  final BaseClient client;

  final Context _p = Context(style: Style.url);

  @override
  Stream<AngelAuthResult> get onAuthenticated => _onAuthenticated.stream;

  BaseAngelClient(this.client, baseUrl) : super(baseUrl);

  @override
  Future<AngelAuthResult> authenticate(
      {String? type, credentials, String authEndpoint = '/auth'}) async {
    type ??= 'token';

    var segments = baseUrl.pathSegments
        .followedBy(_p.split(authEndpoint))
        .followedBy([type]);

    //var p1 = p.joinAll(segments).replaceAll('\\', '/');

    var url = baseUrl.replace(path: _p.joinAll(segments));
    Response response;

    if (credentials != null) {
      response = await post(url,
          body: json.encode(credentials), headers: _writeHeaders);
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
            message: "Auth endpoint '$url' did not return a proper response.");
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
      String method, url, Map<String, String>? headers,
      [body, Encoding? encoding]) async {
    var request = Request(method, url is Uri ? url : Uri.parse(url.toString()));

    if (headers != null) request.headers.addAll(headers);

    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = List<int>.from(body);
      } else if (body is Map<String, dynamic>) {
        request.bodyFields =
            body.map((k, v) => MapEntry(k, v is String ? v : v.toString()));
      } else {
        _log.severe('Body is not a String, List<int>, or Map<String, String>');
        throw ArgumentError.value(body, 'body',
            'must be a String, List<int>, or Map<String, String>.');
      }
    }

    return Response.fromStream(await send(request));
  }

  @override
  Service<Id, Data> service<Id, Data>(String path,
      {Type? type, AngelDeserializer<Data>? deserializer}) {
    var url = baseUrl.replace(path: _p.join(baseUrl.path, path));
    var s = BaseAngelService<Id, Data>(client, this, url,
        deserializer: deserializer);
    _services.add(s);
    return s as Service<Id, Data>;
  }

  Uri _join(url) {
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
  Future<Response> patch(url,
      {body, Map<String, String>? headers, Encoding? encoding}) async {
    return sendUnstreamed('PATCH', _join(url), headers, body, encoding);
  }

  @override
  Future<Response> post(url,
      {body, Map<String, String>? headers, Encoding? encoding}) async {
    return sendUnstreamed('POST', _join(url), headers, body, encoding);
  }

  @override
  Future<Response> put(url,
      {body, Map<String, String>? headers, Encoding? encoding}) async {
    return sendUnstreamed('PUT', _join(url), headers, body, encoding);
  }
}

class BaseAngelService<Id, Data> extends Service<Id, Data?> {
  final _log = Logger('BaseAngelService');

  @override
  final BaseAngelClient app;
  final Uri baseUrl;
  final BaseClient client;
  final AngelDeserializer<Data>? deserializer;

  final Context _p = Context(style: Style.url);

  final StreamController<List<Data?>> _onIndexed = StreamController();
  final StreamController<Data?> _onRead = StreamController(),
      _onCreated = StreamController(),
      _onModified = StreamController(),
      _onUpdated = StreamController(),
      _onRemoved = StreamController();

  @override
  Stream<List<Data?>> get onIndexed => _onIndexed.stream;

  @override
  Stream<Data?> get onRead => _onRead.stream;

  @override
  Stream<Data?> get onCreated => _onCreated.stream;

  @override
  Stream<Data?> get onModified => _onModified.stream;

  @override
  Stream<Data?> get onUpdated => _onUpdated.stream;

  @override
  Stream<Data?> get onRemoved => _onRemoved.stream;

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

  Data? deserialize(x) {
    return deserializer != null ? deserializer!(x) : x as Data?;
  }

  String makeBody(x) {
    //return json.encode(x);
    return jsonEncode(x);
  }

  Future<StreamedResponse> send(BaseRequest request) {
    if (app.authToken != null && app.authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${app.authToken}';
    }

    return client.send(request);
  }

  @override
  Future<List<Data>> index([Map<String, dynamic>? params]) async {
    var url = baseUrl.replace(queryParameters: _buildQuery(params));
    var response = await app.sendUnstreamed('GET', url, _readHeaders);

    try {
      if (_invalid(response)) {
        if (_onIndexed.hasListener) {
          _onIndexed.addError(failure(response));
        } else {
          throw failure(response);
        }
      }

      var v = json.decode(response.body) as List;
      //var r = v.map(deserialize).toList();
      var r = <Data>[];
      for (var element in v) {
        var a = deserialize(element);
        if (a != null) {
          r.add(a);
        }
      }
      _onIndexed.add(r);
      return r;
    } catch (e, st) {
      if (_onIndexed.hasListener) {
        _onIndexed.addError(e, st);
      } else {
        _log.severe(st);
        throw failure(response, error: e, stack: st);
      }
    }

    return [];
  }

  @override
  Future<Data?> read(id, [Map<String, dynamic>? params]) async {
    var pa = _p.join(baseUrl.path, id.toString());
    print(pa);
    var url = baseUrl.replace(
        path: _p.join(baseUrl.path, id.toString()),
        queryParameters: _buildQuery(params));

    var response = await app.sendUnstreamed('GET', url, _readHeaders);

    try {
      if (_invalid(response)) {
        if (_onRead.hasListener) {
          _onRead.addError(failure(response));
        } else {
          throw failure(response);
        }
      }

      var r = deserialize(json.decode(response.body));
      _onRead.add(r);
      return r;
    } catch (e, st) {
      if (_onRead.hasListener) {
        _onRead.addError(e, st);
      } else {
        _log.severe(st);
        throw failure(response, error: e, stack: st);
      }
    }

    return null;
  }

  @override
  Future<Data?> create(data, [Map<String, dynamic>? params]) async {
    var url = baseUrl.replace(queryParameters: _buildQuery(params));
    var response =
        await app.sendUnstreamed('POST', url, _writeHeaders, makeBody(data));

    try {
      if (_invalid(response)) {
        if (_onCreated.hasListener) {
          _onCreated.addError(failure(response));
        } else {
          throw failure(response);
        }
      }

      var r = deserialize(json.decode(response.body));
      _onCreated.add(r);
      return r;
    } catch (e, st) {
      if (_onCreated.hasListener) {
        _onCreated.addError(e, st);
      } else {
        _log.severe(st);
        throw failure(response, error: e, stack: st);
      }
    }

    return null;
  }

  @override
  Future<Data?> modify(id, data, [Map<String, dynamic>? params]) async {
    var url = baseUrl.replace(
        path: _p.join(baseUrl.path, id.toString()),
        queryParameters: _buildQuery(params));

    var response =
        await app.sendUnstreamed('PATCH', url, _writeHeaders, makeBody(data));

    try {
      if (_invalid(response)) {
        if (_onModified.hasListener) {
          _onModified.addError(failure(response));
        } else {
          throw failure(response);
        }
      }

      var r = deserialize(json.decode(response.body));
      _onModified.add(r);
      return r;
    } catch (e, st) {
      if (_onModified.hasListener) {
        _onModified.addError(e, st);
      } else {
        _log.severe(st);
        throw failure(response, error: e, stack: st);
      }
    }

    return null;
  }

  @override
  Future<Data?> update(id, data, [Map<String, dynamic>? params]) async {
    var url = baseUrl.replace(
        path: _p.join(baseUrl.path, id.toString()),
        queryParameters: _buildQuery(params));

    var response =
        await app.sendUnstreamed('POST', url, _writeHeaders, makeBody(data));

    try {
      if (_invalid(response)) {
        if (_onUpdated.hasListener) {
          _onUpdated.addError(failure(response));
        } else {
          throw failure(response);
        }
      }

      var r = deserialize(json.decode(response.body));
      _onUpdated.add(r);
      return r;
    } catch (e, st) {
      if (_onUpdated.hasListener) {
        _onUpdated.addError(e, st);
      } else {
        _log.severe(st);
        throw failure(response, error: e, stack: st);
      }
    }

    return null;
  }

  @override
  Future<Data?> remove(id, [Map<String, dynamic>? params]) async {
    var url = baseUrl.replace(
        path: _p.join(baseUrl.path, id.toString()),
        queryParameters: _buildQuery(params));

    var response = await app.sendUnstreamed('DELETE', url, _readHeaders);

    try {
      if (_invalid(response)) {
        if (_onRemoved.hasListener) {
          _onRemoved.addError(failure(response));
        } else {
          throw failure(response);
        }
      }

      var r = deserialize(json.decode(response.body));
      _onRemoved.add(r);
      return r;
    } catch (e, st) {
      if (_onRemoved.hasListener) {
        _onRemoved.addError(e, st);
      } else {
        _log.severe(st);
        throw failure(response, error: e, stack: st);
      }
    }

    return null;
  }
}
