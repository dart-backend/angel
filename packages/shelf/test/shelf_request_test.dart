import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_shelf/angel3_shelf.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  var app = Angel();

  ShelfRequestContext request(Map<String, String> headers) =>
      ShelfRequestContext(
        app,
        app.container.createChild(),
        shelf.Request('POST', Uri.parse('http://localhost/'), headers: headers),
        '/',
      );

  // The context is still created, with the invalid framing headers removed.
  // (shelf sets Content-Length again for a body of known length, such as
  // these empty ones.)
  Matcher badRequest = predicate<ShelfRequestContext Function()>((create) {
    var rq = create();
    return rq.framingError?.statusCode == 400 &&
        rq.headers.contentLength == (rq.rawRequest.contentLength ?? -1) &&
        rq.headers.contentLength <= 0 &&
        !rq.headers.chunkedTransferEncoding &&
        !rq.rawRequest.headers.containsKey('transfer-encoding');
  }, 'a request context with a 400 framingError and no framing headers');

  test('invalid framing headers are removed from a streamed request', () {
    var rq = ShelfRequestContext(
      app,
      app.container.createChild(),
      shelf.Request(
        'POST',
        Uri.parse('http://localhost/'),
        headers: {'content-length': '5,6'},
        body: Stream.value('hello'.codeUnits),
      ),
      '/',
    );
    expect(rq.framingError?.statusCode, 400);
    expect(rq.rawRequest.headers, isNot(contains('content-length')));
    expect(rq.headers.contentLength, -1);
  });

  test('the request and response know their app', () {
    var app = Angel()..maxBodySize = 1234;
    var rq = ShelfRequestContext(
      app,
      app.container.createChild(),
      shelf.Request('GET', Uri.parse('http://localhost/')),
      '/',
    );
    expect(rq.app, same(app));
    expect(rq.maxBodySize, 1234);
    expect(ShelfResponseContext(app).app, same(app));
  });

  test('ioc with an explicit injection works without a reflector', () async {
    var app = Angel();
    app.get(
      '/hello',
      ioc(
        (String name) => {'hello': name},
        injection: InjectionRequest.constant(
          required: ['name'],
          parameters: {'name': Query('name')},
        ),
      ),
    );
    var response = await AngelShelf(app).handler(
      shelf.Request('GET', Uri.parse('http://localhost/hello?name=bob')),
    );
    expect(response.statusCode, 200);
    expect(json.decode(await response.readAsString()), {'hello': 'bob'});
  });

  test('a valid content-length is kept', () {
    var rq = request({'content-length': '5', 'x-foo': 'bar'});
    expect(rq.framingError, isNull);
    expect(rq.headers.contentLength, 5);
    expect(rq.rawRequest.contentLength, 5);
    expect(rq.headers.value('x-foo'), 'bar');
  });

  test('a malformed content-length is a 400', () {
    expect(() => request({'content-length': 'abc'}), badRequest);
    expect(() => request({'content-length': '5x'}), badRequest);
    expect(() => request({'content-length': ''}), badRequest);
    expect(() => request({'content-length': '-1'}), badRequest);
    expect(() => request({'content-length': '1234567890123456'}), badRequest);
  });

  test('repeated identical content-lengths are collapsed into one', () {
    var rq = request({'content-length': '20000000, 20000000'});
    expect(rq.headers.contentLength, 20000000);
    expect(rq.rawRequest.contentLength, 20000000);
  });

  test('differing content-lengths are a 400', () {
    expect(() => request({'content-length': '5,6'}), badRequest);
  });

  test('content-length with transfer-encoding is a 400, in either order', () {
    expect(
      () => request({'transfer-encoding': 'chunked', 'content-length': '5'}),
      badRequest,
    );
    expect(
      () => request({'content-length': '5', 'transfer-encoding': 'chunked'}),
      badRequest,
    );
  });

  test('transfer-encoding must end in a single chunked', () {
    expect(
      request({'transfer-encoding': 'chunked'}).headers.chunkedTransferEncoding,
      isTrue,
    );
    expect(
      request({'transfer-encoding': 'gzip, chunked'}).rawRequest.headers,
      containsPair('transfer-encoding', 'gzip, chunked'),
    );
    expect(() => request({'transfer-encoding': 'gzip'}), badRequest);
    expect(() => request({'transfer-encoding': 'chunked, gzip'}), badRequest);
    expect(
      () => request({'transfer-encoding': 'chunked, chunked'}),
      badRequest,
    );
    expect(() => request({'transfer-encoding': 'xchunked'}), badRequest);
    expect(() => request({'transfer-encoding': ''}), badRequest);
  });

  test('a checked request is not checked again', () {
    var raw = shelf.Request(
      'POST',
      Uri.parse('http://localhost/'),
      headers: {'content-length': '5, 5'},
    );
    var checked = checkRequestFraming(raw);
    expect(checked, isNot(same(raw)));
    expect(checkRequestFraming(checked), same(checked));
    expect(
      () => checkRequestFraming(
        shelf.Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'content-length': 'abc'},
        ),
      ),
      throwsA(isA<AngelHttpException>()),
    );
  });

  test('AngelShelf.middleware passes the checked request on', () async {
    var driver = AngelShelf(Angel());
    int? innerLength;
    var middleware = driver.middleware((request) {
      innerLength = request.contentLength;
      return shelf.Response.ok('inner');
    });

    var response = await middleware(
      shelf.Request(
        'POST',
        Uri.parse('http://localhost/'),
        headers: {'content-length': '5, 5'},
        body: Stream.value('hello'.codeUnits),
      ),
    );
    expect(response.statusCode, 200);
    expect(innerLength, 5);
  });

  test(
    'AngelShelf answers invalid framing through the error handler',
    () async {
      var app = Angel();
      app.get('/', (req, res) => 'ok');
      app.errorHandler = (e, req, res) {
        res.headers['x-error'] = 'custom';
        return {'status': e.statusCode, 'message': e.message};
      };
      var driver = AngelShelf(app);

      var response = await driver.handler(
        shelf.Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'content-length': 'abc'},
        ),
      );
      expect(response.statusCode, 400);
      expect(response.headers['x-error'], 'custom');
      expect(json.decode(await response.readAsString()), {
        'status': 400,
        'message': 'Invalid Content-Length: abc',
      });

      var middleware = driver.middleware((_) => shelf.Response.ok('inner'));
      response = await middleware(
        shelf.Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'content-length': '5,6'},
        ),
      );
      expect(response.statusCode, 400);
      expect(response.headers['x-error'], 'custom');
    },
  );
}
