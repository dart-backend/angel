import 'dart:convert';

import 'package:http/http.dart' show ClientException, Response;

import 'package:angel3_client/angel3_client.dart';
import 'package:angel3_client/base_angel_client.dart' show failure;
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

    test('have the response status over that of the body', () async {
      client
        ..statusCode = 404
        ..body = json.encode({'is_error': true, 'status_code': 200});
      expect(app.service('todos').read('1'), throwsA(isHttpException(404)));
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
      expect(
        app.service('todos').read('1'),
        throwsA(
          isHttpException(502)
              .having((e) => e.error, 'error', isNull)
              .having((e) => e.stackTrace, 'stackTrace', isNotNull),
        ),
      );
    });

    test('are added to the stream with a stack trace', () async {
      client.statusCode = 404;
      var service = app.service('todos');
      var traces = <StackTrace>[];
      service.onRead.listen(
        (_) {},
        onError: (_, StackTrace st) => traces.add(st),
      );

      await expectLater(service.read('1'), throwsA(isHttpException(404)));
      await Future<void>.delayed(Duration.zero);
      expect(traces, [isNot(StackTrace.empty)]);
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

    test('are a 500 when the body has a 2xx status code', () async {
      client.body = json.encode({'is_error': true, 'status_code': 200});
      var service = app.service<String, int>(
        'todos',
        deserializer: (x) => throw const FormatException('Not an int'),
      );
      expect(service.read('1'), throwsA(isHttpException(500, 'Not an int')));
    });

    test('have a message matching the 500 of a 2xx error body', () {
      var response = Response(
        json.encode({'is_error': true, 'status_code': 200}),
        200,
      );
      expect(failure(response), isHttpException(500, isNot('200')));
    });

    test('keep the message of a 2xx error body', () async {
      client.body = json.encode({'is_error': true, 'message': 'Quota'});
      var service = app.service<String, int>(
        'todos',
        deserializer: (x) => throw const FormatException('Not an int'),
      );
      expect(service.read('1'), throwsA(isHttpException(500, 'Quota')));
    });

    test(
      'say the response could not be read for an empty FormatException',
      () async {
        client.body = json.encode({'text': 'Sleep'});
        var service = app.service<String, int>(
          'todos',
          deserializer: (x) => throw const FormatException(),
        );
        expect(
          service.read('1'),
          throwsA(
            isHttpException(500, startsWith('Could not read the response: ')),
          ),
        );
      },
    );

    test('say the response could not be read', () async {
      client.body = json.encode({'data': []});
      expect(
        app.service('todos').index(),
        throwsA(
          isHttpException(500, startsWith('Could not read the response: ')),
        ),
      );
    });
  });

  test('a typed service without a deserializer says so', () async {
    client.body = json.encode({'text': 'Sleep'});
    expect(
      app.service<String, int>('todos').read('1'),
      throwsA(isHttpException(500, contains('Pass a deserializer'))),
    );
  });

  group('URLs', () {
    test('have no query without params', () async {
      client.body = json.encode([]);
      await app.service('todos').index();
      expect(client.lastRequest!.url.toString(), 'http://localhost:3000/todos');
    });

    test('have the params as query', () async {
      client.body = json.encode({'text': 'Sleep'});
      await app.service('todos').read('1', {'a': 1});
      expect(
        client.lastRequest!.url.toString(),
        'http://localhost:3000/todos/1?a=1',
      );
    });

    test('keep the query of the base URL', () async {
      var app = FixedAngel(client, 'http://localhost:3000/api?key=x');
      client.body = json.encode([]);
      var service = app.service('todos');

      await service.index();
      expect(client.lastRequest!.url.query, 'key=x');
      await service.index({'a': 1});
      expect(client.lastRequest!.url.query, 'key=x&a=1');
      await app.close();
    });

    test('keep the encoding of the base query', () async {
      var app = FixedAngel(client, 'http://localhost:3000/api?sig=a%20b');
      client.body = json.encode([]);
      await app.service('todos').index({'p': 1});
      expect(client.lastRequest!.url.query, 'sig=a%20b&p=1');
      await app.close();
    });

    test('send null as null', () async {
      client.body = json.encode([]);
      await app.service('todos').index({
        'userId': null,
        'tag': ['a', null],
      });
      expect(client.lastRequest!.url.query, 'userId=null&tag=a&tag=null');
    });

    test('reject an empty list, which would drop the filter', () async {
      client.body = json.encode([]);
      await expectLater(
        app.service('todos').index({'tags': []}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'params')),
      );
      expect(client.lastRequest, isNull);
    });

    test('that cannot be built are a failed future', () async {
      var service = app.service('todos');
      for (var call in <Future Function()>[
        () => service.index({'a': _BadToString()}),
        () => service.read('1', {'a': _BadToString()}),
        () => service.remove('1', {'a': _BadToString()}),
      ]) {
        Future? result;
        expect(() => result = call(), returnsNormally);
        await expectLater(result, throwsA(isA<StateError>()));
      }
    });

    test('have one param per value of a list', () async {
      client.body = json.encode([]);
      await app.service('todos').index({
        'tag': ['a', 1],
      });
      expect(client.lastRequest!.url.query, 'tag=a&tag=1');
    });
  });

  group('mapped services', () {
    test('pass the params of create', () async {
      client.body = json.encode('Sleep');
      var service = app
          .service<String, String>('todos')
          .map<int>((s) => s.length, (n) => 'x' * n);
      expect(await service.create(2, {'a': 1}), 5);
      expect(client.lastRequest!.url.query, 'a=1');
    });

    test('pass on a null index', () async {
      var service = _NullIndexService(app).map<int>((s) => s.length, (n) => '');
      expect(await service.index(), isNull);
    });
  });

  test('a typed service given a null body says so', () async {
    client.body = 'null';
    expect(
      app.service<String, int>('todos').read('1'),
      throwsA(isHttpException(500, 'The server returned null, not a int.')),
    );
  });

  test('a FormatException of the deserializer is the message', () async {
    client.body = json.encode({'text': 'Sleep'});
    var service = app.service<String, int>(
      'todos',
      deserializer: (x) => throw const FormatException('Not an int'),
    );
    expect(service.read('1'), throwsA(isHttpException(500, 'Not an int')));
  });

  test(
    'a failure to send is thrown as it is, not added to the stream',
    () async {
      client.error = ClientException('Unreachable');
      var service = app.service('todos');
      var errors = [];
      service.onRead.listen((_) {}, onError: errors.add);

      await expectLater(service.read('1'), throwsA(isA<ClientException>()));
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
    },
  );

  group('data that cannot be encoded', () {
    TypeMatcher<ArgumentError> isEncodeError() => isA<ArgumentError>()
        .having((e) => e.name, 'name', 'data')
        .having((e) => e.message, 'message', contains('JSON'));

    test('is an ArgumentError, not added to the stream', () async {
      var service = app.service('todos');
      var errors = [];
      service.onCreated.listen((_) {}, onError: errors.add);

      await expectLater(service.create(Object()), throwsA(isEncodeError()));
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
      expect(client.lastRequest, isNull);
    });

    test('keeps the stack trace of jsonEncode', () async {
      try {
        await app.service('todos').create(Object());
        fail('create did not throw');
      } on ArgumentError catch (_, st) {
        expect(st.toString(), contains('dart:convert'));
      }
    });

    test('is an ArgumentError for a value a toJson() returns', () async {
      expect(
        app.service('todos').create(_NestedToJson()),
        throwsA(isEncodeError()),
      );
    });

    test('other than a JSON error is thrown as it is', () async {
      expect(
        app.service('todos').create(_BadToJson()),
        throwsA(isA<StateError>()),
      );
    });

    test('is an ArgumentError for modify and update', () async {
      var service = app.service('todos');
      expect(service.modify('1', Object()), throwsA(isEncodeError()));
      expect(service.update('1', Object()), throwsA(isEncodeError()));
    });
  });

  group('a response after the service is closed', () {
    test('is returned', () async {
      client.body = json.encode({'text': 'Sleep'});
      var service = app.service('todos');
      var result = service.read('1');
      await service.close();
      expect(await result, {'text': 'Sleep'});
    });

    test('that is an error is thrown', () async {
      client.statusCode = 404;
      var service = app.service('todos');
      var result = expectLater(
        service.read('1'),
        throwsA(isHttpException(404)),
      );
      await service.close();
      await result;
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

  test('an id is one segment of the path', () async {
    client.body = json.encode({'text': 'Sleep'});
    var service = app.service('api/todos');
    for (var id in ['a/b', '/admin/users', 'a b', '%2E']) {
      await service.remove(id);
      expect(client.lastRequest!.url.pathSegments, ['api', 'todos', id]);
    }
  });

  test('an id that cannot be a path segment is an ArgumentError', () async {
    var service = app.service('todos');
    for (var id in ['', '.', '..']) {
      await expectLater(
        service.remove(id),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'id')),
      );
    }
    expect(client.lastRequest, isNull);
  });

  test('authenticate after close returns its result', () async {
    client.body = json.encode({'token': 'jwt', 'data': {}});
    var result = app.authenticate(type: 'local');
    await app.close();
    expect((await result).token, 'jwt');
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

/// A service whose `index` returns `null`, like a WebSocket service.
class _NullIndexService extends Service<String, String> {
  @override
  final Angel app;

  _NullIndexService(this.app);

  @override
  Future<List<String>?> index([Map<String, dynamic>? params]) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BadToJson {
  Map<String, dynamic> toJson() => throw StateError('Bug in toJson');
}

class _NestedToJson {
  Map<String, dynamic> toJson() => {'owner': Object()};
}

class _BadToString {
  @override
  String toString() => throw StateError('Bad toString');
}
