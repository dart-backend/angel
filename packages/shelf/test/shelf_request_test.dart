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
        shelf.Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: headers,
        ),
        '/',
      );

  Matcher badRequest = throwsA(
    isA<AngelHttpException>().having((e) => e.statusCode, 'statusCode', 400),
  );

  test('a valid content-length is kept', () {
    var rq = request({'content-length': '5', 'x-foo': 'bar'});
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

  test('AngelShelf answers invalid framing with a 400', () async {
    var app = Angel();
    app.get('/', (req, res) => 'ok');
    var driver = AngelShelf(app);

    var response = await driver.handler(
      shelf.Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'content-length': 'abc'},
      ),
    );
    expect(response.statusCode, 400);

    var middleware = driver.middleware((_) => shelf.Response.ok('inner'));
    response = await middleware(
      shelf.Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'content-length': '5,6'},
      ),
    );
    expect(response.statusCode, 400);
  });
}
