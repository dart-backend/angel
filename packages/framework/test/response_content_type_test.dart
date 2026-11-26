import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

/// [ResponseContext.contentType] follows the `content-type` header however
/// it is changed, though parsed headers are reused across responses.
void main() {
  late Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel();
    http = AngelHttp(app);
  });

  tearDown(() => app.close());

  /// Runs [handler] on a request, and returns the content type sent.
  Future<String?> send(void Function(ResponseContext res) handler) async {
    app.get('/', (req, res) {
      handler(res);
      res.write('x');
    });
    var rq = MockHttpRequest('GET', Uri(path: '/'));
    await rq.close();
    await http.handleRequest(rq);
    await rq.response.drain<void>();
    return rq.response.headers.contentType?.mimeType;
  }

  test('is text/plain by default', () async {
    late MediaType seen;
    var sent = await send((res) => seen = res.contentType);
    expect(seen.mimeType, 'text/plain');
    expect(sent, 'text/plain');
  });

  test('follows the header as it is set, changed and removed', () async {
    var seen = <String>[];
    var sent = await send((res) {
      res.headers['content-type'] = 'application/json';
      seen.add(res.contentType.mimeType);
      res.headers['content-type'] = 'text/html; charset=utf-8';
      seen.add('${res.contentType.mimeType} ${res.contentType.parameters}');
      res.headers.remove('content-type');
      seen.add(res.contentType.mimeType);
      res.contentType = MediaType('image', 'png');
      seen.add(res.contentType.mimeType);
    });
    expect(seen, [
      'application/json',
      'text/html {charset: utf-8}',
      'text/plain',
      'image/png',
    ]);
    expect(sent, 'image/png');
  });

  test('is text/plain for a header that does not parse', () async {
    late MediaType seen;
    await send((res) {
      res.headers['content-type'] = 'not a media type';
      seen = res.contentType;
    });
    expect(seen.mimeType, 'text/plain');
  });

  test('is the same for a header sent on several responses', () async {
    var seen = <MediaType>[];
    for (var i = 0; i < 2; i++) {
      app = Angel();
      http = AngelHttp(app);
      await send((res) {
        res.headers['content-type'] = 'text/csv; charset=utf-8';
        seen.add(res.contentType);
      });
      await app.close();
    }
    for (var type in seen) {
      expect(type.mimeType, 'text/csv');
      expect(type.parameters, {'charset': 'utf-8'});
    }
  });

  test('parses each of many distinct headers', () async {
    var seen = <String>[];
    await send((res) {
      for (var i = 0; i < 600; i++) {
        res.headers['content-type'] = 'application/x-type-$i';
        seen.add(res.contentType.mimeType);
      }
    });
    expect(seen, [for (var i = 0; i < 600; i++) 'application/x-type-$i']);
  });
}
