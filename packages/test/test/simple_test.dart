import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:angel3_validate/angel3_validate.dart';
import 'package:angel3_websocket/server.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  Angel app;
  late TestClient client;

  setUp(() async {
    app = Angel()
      ..get('/hello', (req, res) => 'Hello')
      ..get('/buffered', (req, res) {
        res.useBuffer();
        return 'Hello';
      })
      ..get('/user_info', (req, res) => {'u': req.uri?.userInfo})
      ..get(
        '/error',
        (req, res) =>
            throw AngelHttpException.forbidden(message: 'Test')
              ..errors.addAll(['foo', 'bar']),
      )
      ..get('/bare-error', (req, res) {
        res.statusCode = 404;
        return {'is_error': true};
      })
      ..get('/body', (req, res) {
        res
          ..write('OK')
          ..close();
      })
      ..get(
        '/valid',
        (req, res) => {
          'michael': 'jackson',
          'billie': {'jean': 'hee-hee', 'is_my_lover': false},
        },
      )
      ..post('/hello', (req, res) async {
        var body = await req.parseBody().then((_) => req.bodyAsMap);
        return {'bar': body['foo']};
      })
      ..get('/gzip-buffered', (req, res) {
        res
          ..useBuffer()
          ..headers['content-encoding'] = 'gzip'
          ..add(gzip.encode('Poop'.codeUnits));
      })
      ..get('/gzip-list', (req, res) {
        res
          ..useBuffer()
          ..headers['content-encoding'] = 'GZIP, identity'
          ..add(gzip.encode('Poop'.codeUnits));
      })
      ..get('/gzip', (req, res) async {
        res
          ..headers['content-encoding'] = 'gzip'
          ..add(gzip.encode('Poop'.codeUnits));
        await res.close();
      })
      ..use(
        '/foo',
        AnonymousService<String, Map<String, dynamic>>(
          index: ([params]) async => [
            <String, dynamic>{'michael': 'jackson'},
          ],
          create: (data, [params]) async => <String, dynamic>{'foo': 'bar'},
        ),
      );

    var ws = AngelWebSocket(app);
    await app.configure(ws.configureServer);
    app.all('/ws', ws.handleRequest);

    app.errorHandler = (e, req, res) => e.toJson();

    client = await connectTo(app, useZone: false);
  });

  tearDown(() async {
    await client.close();
  });

  group('matchers', () {
    group('isJson+hasStatus', () {
      test('get', () async {
        final response = await client.get(Uri.parse('/hello'));
        expect(response, isJson('Hello'));
      });

      test('post', () async {
        final response = await client.post(
          Uri.parse('/hello'),
          body: {'foo': 'baz'},
        );
        expect(response, allOf(hasStatus(200), isJson({'bar': 'baz'})));
      });
    });

    test('isAngelHttpException', () async {
      var res = await client.get(Uri.parse('/error'));
      print(res.body);
      expect(res, isAngelHttpException());
      expect(
        res,
        isAngelHttpException(
          statusCode: 403,
          message: 'Test',
          errors: ['foo', 'bar'],
        ),
      );
    });

    test('contentLength is the buffered body length', () async {
      var res = await client.send(http.Request('GET', Uri.parse('/buffered')));
      expect(res.contentLength, (await res.stream.toBytes()).length);
    });

    test('contentLength is null when the body is streamed', () async {
      var res = await client.send(http.Request('GET', Uri.parse('/hello')));
      expect(res.contentLength, isNull);
    });

    test('isAngelHttpException uses the HTTP status as a fallback', () async {
      var res = await client.get(Uri.parse('/bare-error'));
      expect(res, isAngelHttpException(statusCode: 404));
    });

    test('userInfo from Uri', () async {
      var url = Uri(userInfo: 'foo:bar', path: '/user_info');
      print('URL: $url');
      var res = await client.get(url);
      print(res.body);
      var m = json.decode(res.body) as Map;
      expect(m, {'u': 'foo:bar'});
    });

    test('userInfo from Basic auth header', () async {
      var url = Uri(path: '/user_info');
      print('URL: $url');
      var res = await client.get(
        url,
        headers: {
          'authorization': 'Basic ${base64Url.encode(utf8.encode('foo:bar'))}',
        },
      );
      print(res.body);
      var m = json.decode(res.body) as Map;
      expect(m, {'u': 'foo:bar'});
    });

    test('hasBody', () async {
      var res = await client.get(Uri.parse('/body'));
      expect(res, hasBody());
      expect(res, hasBody('OK'));
    });

    test('hasHeader', () async {
      var res = await client.get(Uri.parse('/hello'));
      expect(res, hasHeader('server'));
      expect(res, hasHeader('server', 'Angel3'));
      expect(res, hasHeader('server', ['Angel3']));
    });

    test('hasValidBody+hasContentType', () async {
      var res = await client.get(Uri.parse('/valid'));
      print('Body: ${res.body}');
      expect(res, hasContentType('application/json'));
      expect(res, hasContentType(ContentType('application', 'json')));
      expect(
        res,
        hasValidBody(
          Validator({
            'michael*': [isString, isNotEmpty, equals('jackson')],
            'billie': Validator({
              'jean': [isString, isNotEmpty],
              'is_my_lover': [isBool, isFalse],
            }),
          }),
        ),
      );
    });

    test('gzip decode', () async {
      var res = await client.get(Uri.parse('/gzip'));
      print('Body: ${res.body}');
      expect(res, hasHeader('content-encoding', 'gzip'));
      expect(res, hasBody('Poop'));
    });

    test('contentLength is null when the body is decompressed', () async {
      var res = await client.send(
        http.Request('GET', Uri.parse('/gzip-buffered')),
      );
      expect(utf8.decode(await res.stream.toBytes()), 'Poop');
      expect(res.contentLength, isNull);
      expect(res.headers, isNot(contains('content-length')));
    });

    test('gzip is found in a list of encodings, in any case', () async {
      var res = await client.get(Uri.parse('/gzip-list'));
      expect(res.body, 'Poop');
    });

    test('mismatches describe the response', () async {
      String mismatch(Matcher matcher, Object item) {
        var state = {};
        expect(matcher.matches(item, state), isFalse);
        return matcher
            .describeMismatch(item, StringDescription(), state, false)
            .toString();
      }

      var text = await client.get(Uri.parse('/body'));
      expect(mismatch(isJson('OK'), text), contains('not JSON: OK'));

      var error = await client.get(Uri.parse('/error'));
      expect(
        mismatch(isAngelHttpException(statusCode: 404), error),
        allOf(contains('403'), contains('Test'), contains('foo')),
      );

      var valid = await client.get(Uri.parse('/valid'));
      var matcher = hasValidBody(Validator({'michael*': isInt}));
      expect(mismatch(matcher, valid), contains('michael'));
      expect(mismatch(matcher, text), contains('not JSON'));
    });

    test('JSON matchers do not match a body that is not JSON', () async {
      var res = await client.get(Uri.parse('/body'));
      expect(res.body, 'OK');
      expect(res, isNot(isJson('OK')));
      expect(res, isNot(isAngelHttpException()));
      expect(res, isNot(hasValidBody(Validator({'foo': isString}))));
    });

    group('service', () {
      test('can be typed after an untyped one on the same path', () async {
        client.service('foo');
        var foo = client.service<String, String>(
          'foo',
          deserializer: (x) => (x as Map)['michael'] as String,
        );
        expect(await foo.index(), ['jackson']);
      });

      test('index', () async {
        var foo = client.service('foo');
        var result = await foo.index();
        expect(result, [
          <String, dynamic>{'michael': 'jackson'},
        ]);
      });

      test('index', () async {
        var foo = client.service('foo');
        var result = await foo.create({});
        expect(result, <String, dynamic>{'foo': 'bar'});
      });
    });

    test('websocket', () async {
      var ws = await client.websocket();
      var foo = ws.service('foo');
      foo.create(<String, dynamic>{});
      var result = await foo.onCreated.first;
      expect(
        result is Map ? result : result.data,
        equals(<String, dynamic>{'foo': 'bar'}),
      );
    });
  });
}
