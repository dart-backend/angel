import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  var app = Angel();
  var http = AngelHttp(app);

  app.get('/default', (req, res) => res.jsonp({'foo': 'bar'}));

  app.get(
    '/callback',
    (req, res) => res.jsonp({'foo': 'bar'}, callbackName: 'doIt'),
  );

  app.get(
    '/contentType',
    (req, res) =>
        res.jsonp({'foo': 'bar'}, contentType: MediaType('foo', 'bar')),
  );

  app.get(
    '/fromQuery',
    (req, res) => res.jsonp({
      'foo': 'bar',
    }, callbackName: req.queryParameters['callback'] ?? 'callback'),
  );

  app.get('/asyncSerializer', (req, res) {
    res.serializer = (value) async => json.encode(value);
    return res.jsonp({'foo': 'bar'});
  });

  Future<MediaType> getContentType(String path) async {
    var rq = MockHttpRequest('GET', Uri(path: '/$path'));
    await rq.close();
    await http.handleRequest(rq);
    return MediaType.parse(rq.response.headers.contentType.toString());
  }

  Future<String> getText(String path) async {
    var rq = MockHttpRequest('GET', Uri.parse('/$path'));
    await rq.close();
    await http.handleRequest(rq);
    return await rq.response.transform(utf8.decoder).join();
  }

  test('default', () async {
    var response = await getText('default');
    var contentType = await getContentType('default');
    expect(response, r'callback({"foo":"bar"})');
    expect(contentType.mimeType, 'application/javascript');
  });

  test('callback', () async {
    var response = await getText('callback');
    var contentType = await getContentType('callback');
    expect(response, r'doIt({"foo":"bar"})');
    expect(contentType.mimeType, 'application/javascript');
  });

  test('content type', () async {
    var response = await getText('contentType');
    var contentType = await getContentType('contentType');
    expect(response, r'callback({"foo":"bar"})');
    expect(contentType.mimeType, 'foo/bar');
  });

  test('accepts a dotted callback name', () async {
    expect(
      await getText('fromQuery?callback=app.cb_1'),
      r'app.cb_1({"foo":"bar"})',
    );
  });

  test('rejects a callback name that is not an identifier', () async {
    var rq = MockHttpRequest(
      'GET',
      Uri(path: '/fromQuery', queryParameters: {'callback': 'alert(1);x'}),
    );
    await rq.close();
    await http.handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    expect(rq.response.statusCode, 400);
    expect(body, isNot(contains('alert')));
  });

  test('awaits an async serializer', () async {
    expect(await getText('asyncSerializer'), r'callback({"foo":"bar"})');
  });
}
