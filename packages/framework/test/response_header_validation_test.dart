import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

/// Response headers are checked as they are set with `[]=`; those set by a
/// map method that bypasses it are checked before they are sent.
void main() {
  group('isValidHeaderName', () {
    // The rule as it was written: an RFC 9110 token.
    var token = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

    test('accepts the characters of a token, and only those', () {
      for (var c = 0; c < 0x180; c++) {
        var name = String.fromCharCode(c);
        expect(
          ResponseContext.isValidHeaderName(name),
          token.hasMatch(name),
          reason: 'U+${c.toRadixString(16).padLeft(4, '0')}',
        );
      }
    });

    test('checks every character of a name', () {
      for (var name in ['x-name', 'X-Name_2', 'a b', 'x:y', 'ok\n', 'é-x']) {
        expect(
          ResponseContext.isValidHeaderName(name),
          token.hasMatch(name),
          reason: name,
        );
      }
      expect(ResponseContext.isValidHeaderName(''), isFalse);
    });
  });

  group('a header set by a method that bypasses []=', () {
    late Angel app;
    late AngelHttp http;

    setUp(() {
      app = Angel();
      http = AngelHttp(app);
    });

    tearDown(() => app.close());

    /// The status and the `x-name` header sent for [handler].
    Future<(int, String?)> send(
      void Function(ResponseContext res) handler,
    ) async {
      app.get('/', (req, res) {
        handler(res);
        return 'body';
      });
      var rq = MockHttpRequest('GET', Uri(path: '/'));
      await rq.close();
      await http.handleRequest(rq);
      await rq.response.drain<void>();
      return (rq.response.statusCode, rq.response.headers.value('x-name'));
    }

    test('by update fails the response if invalid', () async {
      var (status, header) = await send((res) {
        res.headers['x-name'] = 'plain';
        res.headers.update('x-name', (_) => 'café');
      });
      expect(status, 500);
      expect(header, isNull);
    });

    test('by updateAll fails the response if invalid', () async {
      var (status, _) = await send((res) {
        res.headers['x-name'] = 'plain';
        res.headers.updateAll((k, v) => k == 'x-name' ? 'café' : v);
      });
      expect(status, 500);
    });

    test('by addEntries fails the response if invalid', () async {
      var (status, header) = await send((res) {
        res.headers.addEntries([const MapEntry('x-name', 'café')]);
      });
      expect(status, 500);
      expect(header, isNull);
    });

    test('by addEntries fails the response if its name is invalid', () async {
      var (status, _) = await send((res) {
        res.headers.addEntries([const MapEntry('x name', 'value')]);
      });
      expect(status, 500);
    });

    test('is sent if valid', () async {
      var (status, header) = await send((res) {
        res.headers.putIfAbsent('x-name', () => 'plain');
      });
      expect(status, 200);
      expect(header, 'plain');
    });

    test('is checked again after an earlier check passed', () async {
      var (status, _) = await send((res) {
        res.headers.putIfAbsent('x-name', () => 'plain');
        res.validateHeaders();
        res.headers.update('x-name', (_) => 'café');
      });
      expect(status, 500);
    });
  });

  test('a response of headers set with []= only is sent', () async {
    var app = Angel();
    var http = AngelHttp(app);
    app.get('/', (req, res) {
      res.headers['x-name'] = 'plain value\twith tab';
      // Written, not returned: a returned value is sent as JSON.
      res.write('body');
    });
    var rq = MockHttpRequest('GET', Uri(path: '/'));
    await rq.close();
    await http.handleRequest(rq);
    await rq.response.drain<void>();
    expect(rq.response.statusCode, 200);
    expect(rq.response.headers.value('x-name'), 'plain value\twith tab');
    expect(rq.response.headers.value('server'), 'Angel3');
    expect(rq.response.headers.contentType?.mimeType, 'text/plain');
    await app.close();
  });
}
