import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

class Todo extends Model {
  String? text;
  String? over;
}

void main() {
  Map headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  late Angel app;
  late MapService service;
  late String url;
  late http.Client client;

  setUp(() async {
    app = Angel(reflector: MirrorsReflector())
      ..use('/todos', service = MapService())
      ..errorHandler = (e, req, res) {
        if (e.error != null) print('Whoops: ${e.error}');
        if (e.stackTrace != null) print(Chain.forTrace(e.stackTrace!).terse);
      };

    var server = await AngelHttp(app).startServer();
    client = http.Client();
    url = 'http://${server.address.host}:${server.port}';
  });

  tearDown(() async {
    await app.close();
    client.close();
  });

  group('memory', () {
    test('can index an empty service', () async {
      var response = await client.get(Uri.parse('$url/todos/'));
      print(response.body);
      expect(response.body, equals('[]'));
      print(response.body);
      expect(json.decode(response.body).length, 0);
    });

    test('can create data', () async {
      var postData = json.encode({'text': 'Hello, world!'});
      var response = await client.post(
        Uri.parse('$url/todos'),
        headers: headers as Map<String, String>,
        body: postData,
      );
      expect(response.statusCode, 201);
      var jsons = json.decode(response.body);
      print(jsons);
      expect(jsons['text'], equals('Hello, world!'));
    });

    test('can fetch data', () async {
      var postData = json.encode({'text': 'Hello, world!'});
      await client.post(
        Uri.parse('$url/todos'),
        headers: headers as Map<String, String>,
        body: postData,
      );
      var response = await client.get(Uri.parse('$url/todos/0'));
      expect(response.statusCode, 200);
      var jsons = json.decode(response.body);
      print(jsons);
      expect(jsons['text'], equals('Hello, world!'));
    });

    test('can modify data', () async {
      var postData = json.encode({'text': 'Hello, world!'});
      await client.post(
        Uri.parse('$url/todos'),
        headers: headers as Map<String, String>,
        body: postData,
      );
      postData = json.encode({'text': 'modified'});

      var response = await client.patch(
        Uri.parse('$url/todos/0'),
        headers: headers,
        body: postData,
      );
      expect(response.statusCode, 200);
      var jsons = json.decode(response.body);
      print(jsons);
      expect(jsons['text'], equals('modified'));
    });

    test('can overwrite data', () async {
      var postData = json.encode({'text': 'Hello, world!'});
      await client.post(
        Uri.parse('$url/todos'),
        headers: headers as Map<String, String>,
        body: postData,
      );
      postData = json.encode({'over': 'write'});

      var response = await client.post(
        Uri.parse('$url/todos/0'),
        headers: headers,
        body: postData,
      );
      expect(response.statusCode, 200);
      var jsons = json.decode(response.body);
      print(jsons);
      expect(jsons['text'], equals(null));
      expect(jsons['over'], equals('write'));
    });

    test('readMany', () async {
      var items = <Map>[
        await service.create({'foo': 'bar'}),
        await service.create({'bar': 'baz'}),
        await service.create({'baz': 'quux'}),
      ];

      var ids = items.map((m) => m['id'] as String?).toList();
      expect(await service.readMany(ids), items);
    });

    test('can delete data', () async {
      var postData = json.encode({'text': 'Hello, world!'});
      var created = await client
          .post(
            Uri.parse('$url/todos'),
            headers: headers as Map<String, String>,
            body: postData,
          )
          .then((r) => json.decode(r.body));
      var response = await client.delete(
        Uri.parse("$url/todos/${created['id']}"),
      );
      expect(response.statusCode, 200);
      var json_ = json.decode(response.body);
      print(json_);
      expect(json_['text'], equals('Hello, world!'));
    });

    test('cannot remove all unless explicitly set', () async {
      var response = await client.delete(Uri.parse('$url/todos/null'));
      expect(response.statusCode, 403);
    });

    test(
      'DELETE / requests remove all, which is forbidden by default',
      () async {
        var response = await client.delete(Uri.parse('$url/todos'));
        expect(response.statusCode, 403);
      },
    );

    test('does not reuse ids after removal', () async {
      Future<String> create(String text) async {
        var response = await client.post(
          Uri.parse('$url/todos'),
          headers: headers as Map<String, String>,
          body: json.encode({'text': text}),
        );
        return json.decode(response.body)['id'] as String;
      }

      var first = await create('a');
      var second = await create('b');
      await client.delete(Uri.parse('$url/todos/$first'));
      var third = await create('c');

      expect(third, isNot(second));
      expect(
        service.items.map((i) => i['id']),
        unorderedEquals([second, third]),
      );
    });

    test('skips ids already present in items', () async {
      service.items.add({'id': '0', 'text': 'seeded'});
      var created = await service.create({'text': 'new'});
      expect(created['id'], isNot('0'));
    });
  });

  group('int ids', () {
    setUp(() {
      app.use(
        '/ints',
        AnonymousService<int, Map<String, dynamic>>(
          read: (id, [params]) async => {'id': id},
        ),
      );
    });

    test('are parsed with the wrapped service Id type', () async {
      var response = await client.get(Uri.parse('$url/ints/5'));
      expect(response.statusCode, 200);
      expect(json.decode(response.body), {'id': 5});
    });

    for (var id in ['null', 'abc']) {
      test('"$id" is a 400', () async {
        var response = await client.get(
          Uri.parse('$url/ints/$id'),
          headers: {'accept': 'application/json'},
        );
        expect(response.statusCode, 400);
      });
    }
  });

  group('parseId', () {
    test('parses nullable types like their non-nullable form', () {
      expect(Service.parseId<int?>('5'), 5);
      expect(Service.parseId<double?>('1.5'), 1.5);
      expect(Service.parseId<String?>(5), '5');
    });

    test('passes "null" only to types that accept a String', () {
      expect(Service.parseId<String>(null), 'null');
      expect(Service.parseId<dynamic>('null'), 'null');
      expect(() => Service.parseId<int>('null'), throwsFormatException);
      expect(() => Service.parseId<int?>(null), throwsFormatException);
    });
  });

  test('DELETE / is not allowed for non-String ids', () async {
    app.use(
      '/numbers',
      AnonymousService<int, Map<String, dynamic>>(
        remove: (id, [params]) async => {'removed': id},
      ),
    );
    var response = await client.delete(Uri.parse('$url/numbers'));
    expect(response.statusCode, 405);
  });
}
