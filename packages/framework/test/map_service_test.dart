import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  late MapService service;

  setUp(() async {
    service = MapService();
    for (var (text, done, rank) in [
      ('b', false, 2),
      ('a', true, 3),
      ('c', false, 1),
    ]) {
      await service.create({'text': text, 'done': done, 'rank': rank});
    }
  });

  List<Object?> texts(List<Map<String, dynamic>> items) =>
      items.map((i) => i['text']).toList();

  group('index', () {
    test('does not use special query keys as filters', () async {
      var result = await service.index({
        'query': {r'$sort': 'text', 'page': '1', 'token': 'x'},
      });
      expect(result, hasLength(3));
    });

    test(r'applies $limit from the query or params', () async {
      expect(
        await service.index({
          'query': {r'$limit': '2'},
        }),
        hasLength(2),
      );
      expect(await service.index({r'$limit': 1}), hasLength(1));
      expect(
        await service.index({
          'query': {r'$limit': '10'},
        }),
        hasLength(3),
      );
    });

    test(r'rejects an invalid $limit', () {
      expect(
        () => service.index({
          'query': {r'$limit': '-1'},
        }),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
    });

    test(r'sorts ascending by a field name', () async {
      var result = await service.index({
        'query': {r'$sort': 'text'},
      });
      expect(texts(result), ['a', 'b', 'c']);
    });

    test(r'sorts by a map of fields to 1 / -1', () async {
      var result = await service.index({
        r'$sort': {'rank': -1},
      });
      expect(texts(result), ['a', 'b', 'c']);

      result = await service.index({
        r'$sort': {'done': 1, 'rank': '-1'},
      });
      expect(texts(result), ['b', 'c', 'a']);
    });

    test(r'sorts missing values last, keeping ties stable', () async {
      await service.create({'text': 'no rank'});
      var result = await service.index({r'$sort': 'rank'});
      expect(texts(result), ['c', 'b', 'a', 'no rank']);

      result = await service.index({r'$sort': 'done'});
      expect(texts(result), ['b', 'c', 'a', 'no rank']);
    });

    test(r'combines filter, $sort and $limit', () async {
      var result = await service.index({
        'query': {'done': 'false', r'$sort': 'text', r'$limit': '1'},
      });
      expect(texts(result), ['b']);
    });

    test('matches string query values against other types', () async {
      expect(
        texts(
          await service.index({
            'query': {'done': 'true'},
          }),
        ),
        ['a'],
      );
      expect(
        texts(
          await service.index({
            'query': {'rank': '1'},
          }),
        ),
        ['c'],
      );
      expect(
        texts(
          await service.index({
            'query': {'done': true},
          }),
        ),
        ['a'],
      );
    });

    test('ignores the query when allowQuery is false', () async {
      var closed = MapService(allowQuery: false);
      await closed.create({'text': 'x'});
      await closed.create({'text': 'y'});
      var result = await closed.index({
        'query': {'text': 'y', r'$limit': '1'},
      });
      expect(result, hasLength(2));
    });

    test('returns a copy of the items', () async {
      var result = await service.index();
      result.clear();
      expect(service.items, hasLength(3));
    });
  });

  group('modify (PATCH)', () {
    test('a missing id is a 404 and creates nothing', () async {
      await expectLater(
        service.modify('99', {'text': 'z'}),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      expect(service.items, hasLength(3));
    });

    test('merges into an existing record', () async {
      var result = await service.modify('0', {'text': 'B'});
      expect(result['text'], 'B');
      expect(result['rank'], 2);
    });
  });

  group('update (PUT)', () {
    test('a missing id creates the record at that id', () async {
      var result = await service.update('custom', {'text': 'z'});
      expect(result['id'], 'custom');
      expect(result['created_at'], isNotNull);
      expect((await service.read('custom'))['text'], 'z');
    });

    test('new ids skip ids created by update', () async {
      await service.update('3', {'text': 'taken'});
      var created = await service.create({'text': 'next'});
      expect(created['id'], isNot('3'));
    });

    test('keeps the client id when autoIdAndDateFields is off', () async {
      var plain = MapService(autoIdAndDateFields: false);
      var kept = await plain.update('1', {'id': 1, 'text': 'z'});
      expect(kept, {'id': 1, 'text': 'z'});

      var filled = await plain.update('2', {'text': 'y'});
      expect(filled, {'text': 'y', 'id': '2'});
    });

    test('rejects a "null" id', () {
      expect(
        () => service.update('null', {'text': 'z'}),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
    });
  });

  group('over REST', () {
    late AngelHttp http;

    setUp(() {
      var app = Angel()..use('/todos', service);
      http = AngelHttp(app);
    });

    Future<(int, dynamic)> send(
      String method,
      String url, [
      Object? body,
    ]) async {
      var rq = MockHttpRequest(method, Uri.parse(url))
        ..headers.set('accept', 'application/json');
      if (body != null) {
        rq
          ..headers.set('content-type', 'application/json')
          ..write(json.encode(body));
      }
      await rq.close();
      await http.handleRequest(rq);
      var text = await rq.response.transform(utf8.decoder).join();
      return (rq.response.statusCode, json.decode(text));
    }

    test(r'GET applies $sort and $limit', () async {
      var (status, body) = await send('GET', r'/todos?$sort=text&$limit=2');
      expect(status, 200);
      expect((body as List).map((i) => i['text']), ['a', 'b']);
    });

    test('PATCH on a missing id is a 404', () async {
      var (status, _) = await send('PATCH', '/todos/99', {'text': 'z'});
      expect(status, 404);
    });

    test('PUT on a missing id creates it there', () async {
      var (status, body) = await send('PUT', '/todos/abc', {'text': 'z'});
      expect(status, 200);
      expect(body['id'], 'abc');
    });
  });
}
