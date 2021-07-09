import 'dart:async';
import 'package:angel3_client/base_angel_client.dart';
import 'dart:convert';
import 'package:http/src/base_client.dart' as http;
import 'package:http/src/base_request.dart' as http;
import 'package:http/src/streamed_response.dart' as http;

Future<String> read(Stream<List<int>> stream) =>
    stream.transform(utf8.decoder).join();

class MockAngel extends BaseAngelClient {
  @override
  final SpecClient client = SpecClient();

  MockAngel() : super(SpecClient(), 'http://localhost:3000');

  @override
  Stream<String> authenticateViaPopup(String url,
      {String eventName = 'token'}) {
    throw UnsupportedError('Nope');
  }
}

class SpecClient extends http.BaseClient {
  Spec? _spec;

  Spec? get spec => _spec;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _spec = Spec(request, request.method, request.url.path, request.headers,
        request.contentLength);
    dynamic data = {'text': 'Clean your room!', 'completed': true};

    if (request.url.path.contains('auth')) {
      data = {
        'token': '<jwt>',
        'data': {'username': 'password'}
      };
    } else if (request.url.path == '/api/todos' && request.method == 'GET') {
      data = [data];
    }

    return Future<http.StreamedResponse>.value(http.StreamedResponse(
      Stream<List<int>>.fromIterable([utf8.encode(json.encode(data))]),
      200,
      headers: {
        'content-type': 'application/json',
      },
    ));
  }
}

class Spec {
  final http.BaseRequest request;
  final String method, path;
  final Map<String, String> headers;
  final int? contentLength;

  Spec(this.request, this.method, this.path, this.headers, this.contentLength);

  @override
  String toString() {
    return {
      'method': method,
      'path': path,
      'headers': headers,
      'content_length': contentLength,
    }.toString();
  }
}
