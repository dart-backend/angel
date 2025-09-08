import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:angel3_validate/angel3_validate.dart';
import 'package:angel3_websocket/server.dart';
import 'package:test/test.dart';

void main() {
  Angel app;
  late TestClient client;

  setUp(() async {
    app = Angel()
      ..get('/hello', (req, res) => 'Hello')
      ..get(
        '/error',
        (req, res) =>
            throw AngelHttpException.forbidden(message: 'Test')
              ..errors.addAll(['foo', 'bar']),
      )
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
      ..get('/gzip', (req, res) async {
        res
          ..headers['content-encoding'] = 'gzip'
          ..add(gzip.encode('Poop'.codeUnits));
        await res.close();
      })
      ..use(
        '/foo',
        AnonymousService(
          index: ([params]) async => [
            {'michael': 'jackson'},
          ],
          create: (dynamic data, [params]) async => {'foo': 'bar'},
        ),
      );

    var ws = AngelWebSocket(app);
    await app.configure(ws.configureServer);
    app.all('/ws', ws.handleRequest);

    app.errorHandler = (e, req, res) => e.toJson();

    client = await connectTo(app);
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

    test('hasBody', () async {
      var res = await client.get(Uri.parse('/body'));
      expect(res, hasBody());
      expect(res, hasBody('OK'));
    });

    test('hasHeader', () async {
      var res = await client.get(Uri.parse('/hello'));
      expect(res, hasHeader('server'));
      expect(res, hasHeader('server', 'angel'));
      expect(res, hasHeader('server', ['angel']));
    });

    test('hasValidBody+hasContentType', () async {
      var res = await client.get(Uri.parse('/valid'));
      expect(res, hasContentType('application/json'));
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
      expect(res, hasHeader('content-encoding', 'gzip'));
      expect(res, hasBody('Poop'));
    });

    group('service', () {
      test('index', () async {
        var foo = client.service('foo');
        var result = await foo.index();
        expect(result, [
          {'michael': 'jackson'},
        ]);
      });

      test('index', () async {
        var foo = client.service('foo');
        var result = await foo.create({});
        expect(result, {'foo': 'bar'});
      });
    });

    test('websocket', () async {
      var ws = await client.websocket();
      var foo = ws.service('foo');
      await foo.create({});
      var result = await foo.onCreated.first;
      expect(result.data, equals({'foo': 'bar'}));
    });
  });
}
