import 'dart:async';
import 'dart:io';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

final Uri endpoint = Uri.parse('http://example.com/accept');

void main() {
  test('no content type', () async {
    var req = await acceptContentTypes();
    expect(req.acceptsAll, isFalse);
    //expect(req.accepts(ContentType.JSON), isFalse);
    expect(req.accepts('application/json'), isFalse);
    //expect(req.accepts(ContentType.HTML), isFalse);
    expect(req.accepts('text/html'), isFalse);
  });

  test('wildcard', () async {
    var req = await acceptContentTypes(['*/*']);
    expect(req.acceptsAll, isTrue);
    //expect(req.accepts(ContentType.JSON), isTrue);
    expect(req.accepts('application/json'), isTrue);
    //expect(req.accepts(ContentType.HTML), isTrue);
    expect(req.accepts('text/html'), isTrue);
  });

  test('specific type', () async {
    var req = await acceptContentTypes(['text/html']);
    expect(req.acceptsAll, isFalse);
    //expect(req.accepts(ContentType.JSON), isFalse);
    expect(req.accepts('application/json'), isFalse);
    //expect(req.accepts(ContentType.HTML), isTrue);
    expect(req.accepts('text/html'), isTrue);
  });

  test('strict', () async {
    var req = await acceptContentTypes(['text/html', '*/*']);
    expect(req.accepts('text/html'), isTrue);
    //expect(req.accepts(ContentType.HTML), isTrue);
    //expect(req.accepts(ContentType.JSON, strict: true), isFalse);
    expect(req.accepts('application/json', strict: true), isFalse);
  });

  test('does not match by substring', () async {
    var req = await acceptContentTypes(['application/json-patch+json']);
    expect(req.accepts('application/json'), isFalse);
    expect(req.accepts('application/json-patch+json'), isTrue);
  });

  test('type wildcards', () async {
    var req = await acceptContentTypes(['text/*']);
    expect(req.accepts('text/html'), isTrue);
    expect(req.accepts('text/plain', strict: true), isTrue);
    expect(req.accepts('application/json'), isFalse);
    expect(req.acceptsAll, isFalse);
  });

  test('q=0 means not acceptable', () async {
    var req = await acceptContentTypes([
      'application/json;q=0',
      'text/html; q=0.0',
      'text/plain;q=0.5',
    ]);
    expect(req.accepts('application/json'), isFalse);
    expect(req.accepts('text/html'), isFalse);
    expect(req.accepts('text/plain'), isTrue);
  });

  test('a rejected */* does not accept everything', () async {
    var req = await acceptContentTypes(['text/html', '*/*;q=0']);
    expect(req.acceptsAll, isFalse);
    expect(req.accepts('application/json'), isFalse);
  });

  test('ignores case and parameters', () async {
    var req = await acceptContentTypes(['Text/HTML; charset=utf-8']);
    expect(req.accepts('text/html'), isTrue);
    expect(
      req.accepts(MediaType('text', 'html', {'charset': 'utf-8'})),
      isTrue,
    );
    expect(req.accepts('text/html; charset=utf-8'), isTrue);
  });

  group('disallow null', () {
    late RequestContext req;

    setUp(() async {
      req = await acceptContentTypes();
    });

    test('throws error', () {
      expect(() => req.accepts(null), throwsArgumentError);
    });
  });
}

Future<RequestContext> acceptContentTypes([
  Iterable<String> contentTypes = const [],
]) {
  var headerString = contentTypes.isEmpty
      ? ContentType.text
      : contentTypes.join(',');
  var rq = MockHttpRequest('GET', endpoint, persistentConnection: false);
  rq.headers.set('accept', headerString);
  rq.close();
  var app = Angel(reflector: MirrorsReflector());
  var http = AngelHttp(app);
  return http.createRequestContext(rq, rq.response);
}
