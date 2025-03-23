import 'dart:async';
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

final Uri endpoint = Uri.parse('http://example.com');

void main() {
  test('single extension', () async {
    var req = await makeRequest('foo.js');
    expect(req.extension, '.js');
  });

  test('multiple extensions', () async {
    var req = await makeRequest('foo.min.js');
    expect(req.extension, '.js');
  });

  test('no extension', () async {
    var req = await makeRequest('foo');
    expect(req.extension, '');
  });
}

Future<RequestContext> makeRequest(String path) {
  var rq = MockHttpRequest('GET', endpoint.replace(path: path))..close();
  var app = Angel(reflector: MirrorsReflector());
  var http = AngelHttp(app);
  return http.createRequestContext(rq, rq.response);
}
