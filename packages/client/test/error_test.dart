import 'dart:convert';

import 'package:angel3_client/angel3_client.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  late FixedClient client;
  late FixedAngel app;

  setUp(() {
    client = FixedClient();
    app = FixedAngel(client);
  });

  tearDown(() => app.close());

  TypeMatcher<AngelHttpException> isHttpException(
    int statusCode, [
    Object? message,
  ]) => isA<AngelHttpException>()
      .having((e) => e.statusCode, 'statusCode', statusCode)
      .having((e) => e.message, 'message', message ?? anything);

  group('error responses', () {
    test('use the server error', () async {
      client
        ..statusCode = 404
        ..body = json.encode({
          'is_error': true,
          'status_code': 404,
          'message': 'No todo',
        });
      expect(
        app.service('todos').read('1'),
        throwsA(isHttpException(404, 'No todo')),
      );
    });

    test('without a status code have the response status', () async {
      client
        ..statusCode = 404
        ..body = json.encode({'is_error': true});
      expect(app.service('todos').read('1'), throwsA(isHttpException(404)));
    });

    test('that are not a JSON object have the response status', () async {
      client
        ..statusCode = 400
        ..body = json.encode(['bad']);
      expect(app.service('todos').index(), throwsA(isHttpException(400)));
    });

    test('that are not JSON have the response status', () async {
      client
        ..statusCode = 502
        ..body = '<html>Bad gateway</html>';
      expect(app.service('todos').read('1'), throwsA(isHttpException(502)));
    });

    test('are thrown and added to the stream once', () async {
      client
        ..statusCode = 404
        ..body = json.encode({'is_error': true, 'message': 'No todos'});
      var service = app.service('todos');
      var errors = [];
      service.onIndexed.listen((_) {}, onError: errors.add);

      await expectLater(
        service.index(),
        throwsA(isHttpException(404, 'No todos')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors, [isHttpException(404, 'No todos')]);
    });
  });

  group('failures after a successful response', () {
    test('are a 500 carrying the error', () async {
      client.body = json.encode({'text': 'Sleep'});
      var service = app.service<String, int>(
        'todos',
        deserializer: (x) => throw const FormatException('Not an int'),
      );
      expect(
        service.read('1'),
        throwsA(
          isHttpException(500)
              .having((e) => e.error, 'error', isA<FormatException>()),
        ),
      );
    });

    test('of a list are a 500', () async {
      client.body = json.encode({'text': 'Sleep'});
      expect(app.service('todos').index(), throwsA(isHttpException(500)));
    });
  });

  test('close completes without listeners', () async {
    var app = FixedAngel(FixedClient());
    app.service('todos');
    await app.close().timeout(const Duration(seconds: 5));
  });

  test('services can have a non-nullable type', () async {
    client.body = json.encode({'text': 'Sleep'});
    var service = app.service<String, Map>('todos');
    var events = <Map>[];
    service.onRead.listen(events.add);

    expect(await service.read('1'), {'text': 'Sleep'});
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      {'text': 'Sleep'},
    ]);
  });

  test('a redirect keeps its status', () async {
    client.statusCode = 304;
    expect(app.service('todos').read('1'), throwsA(isHttpException(304)));
  });

  test('a null id is part of the path', () async {
    client.body = json.encode({'text': 'Sleep'});
    await app.service('todos').remove(null);
    expect(client.lastRequest!.method, 'DELETE');
    expect(client.lastRequest!.url.path, '/todos/null');
  });

  test('index skips items deserialized to null', () async {
    client.body = json.encode([1, 'two', 3]);
    var service = app.service<String, int>(
      'numbers',
      deserializer: (x) => x is int ? x : null,
    );
    expect(await service.index(), [1, 3]);
  });

  test('ServiceList passes on errors', () async {
    client
      ..statusCode = 404
      ..body = json.encode({'is_error': true});
    var service = app.service('todos');
    var list = ServiceList(service);
    var errors = [];
    list.onChange.listen((_) {}, onError: errors.add);

    await expectLater(service.index(), throwsA(isHttpException(404)));
    await Future<void>.delayed(Duration.zero);
    expect(errors, [isHttpException(404)]);
    await list.close();
  });
}
