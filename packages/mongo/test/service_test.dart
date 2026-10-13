import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:http/http.dart' as http;
import 'package:angel3_mongo/angel3_mongo.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

/// The MongoDB server the tests use: `MONGO_HOST`, or `localhost`.
final String mongoHost = Platform.environment['MONGO_HOST'] ?? 'localhost';

/// Parameters as a REST request passes them.
Map<String, dynamic> rest([Map<String, dynamic> query = const {}]) => {
  'provider': Providers.rest,
  'query': Map<String, dynamic>.of(query),
};

void main() {
  late Db db;
  late DbCollection collection;
  late MongoService service;

  Matcher throwsStatus(int code) => throwsA(
    isA<AngelHttpException>().having((e) => e.statusCode, 'statusCode', code),
  );

  setUp(() async {
    db = Db('mongodb://$mongoHost:27017/testDB');
    await db.open();
    await db.authenticate("root", "Qwerty", authDb: "admin");
    collection = db.collection('serviceTest');
    await collection.deleteMany(<String, dynamic>{});
    service = MongoService(collection);
  });

  tearDown(() async {
    await collection.deleteMany(<String, dynamic>{});
    await db.close();
  });

  group('create', () {
    test('adds a document for each REST request', () async {
      var a = await service.create({'to': 'a'}, rest());
      var b = await service.create({'to': 'b'}, rest());
      expect(a['id'], isNot(b['id']));
      expect(await collection.count(), 2);
    });

    test('does not store client-set ids or timestamps', () async {
      var created = await service.create({
        '_id': 'abc',
        'id': 'x',
        'createdAt': 'forged',
        'updatedAt': 'forged',
        'to': 'a',
      });
      var raw = (await collection.findOne(<String, dynamic>{}))!;
      expect(raw['_id'], isA<ObjectId>());
      expect(raw.containsKey('id'), isFalse);
      expect(raw['createdAt'], isNot('forged'));
      expect(raw['updatedAt'], isNot('forged'));
      expect(created['id'], (raw['_id'] as ObjectId).oid);
      expect(created['to'], 'a');
    });

    test('sets createdAt and updatedAt', () async {
      var created = await service.create({'to': 'a'});
      expect(DateTime.parse(created['createdAt'] as String), isA<DateTime>());
      expect(created['updatedAt'], created['createdAt']);
    });
  });

  group('query string', () {
    Future<List<String?>> titles(Map<String, dynamic> query) async => [
      for (var d in await service.index(rest(query))) d['to'] as String?,
    ];

    setUp(() async {
      for (var (to, rank) in [('b', 1), ('a', 2), ('c', 1)]) {
        await service.create({'to': to, 'rank': rank});
      }
    });

    test(r'$sort sorts ascending by a field', () async {
      expect(await titles({r'$sort': 'to'}), ['a', 'b', 'c']);
    });

    test(r'$sort sorts descending by a field starting with -', () async {
      expect(await titles({r'$sort': '-to'}), ['c', 'b', 'a']);
    });

    test(r'$sort takes several fields', () async {
      expect(await titles({r'$sort': 'rank,-to'}), ['c', 'b', 'a']);
    });

    test(r'$sort combines with filters', () async {
      expect(await titles({r'$sort': '-to', 'rank': 1}), ['c', 'b']);
    });

    test(r'$limit limits the results', () async {
      expect(await titles({r'$sort': 'to', r'$limit': '2'}), ['a', 'b']);
    });

    test(r'a malformed $limit is a 400', () {
      expect(() => titles({r'$limit': 'x'}), throwsStatus(400));
    });

    test('special keys such as token are not filters', () async {
      expect(await titles({'token': 'abc', 'page': '1'}), hasLength(3));
    });

    test(r'allowQuery: false ignores a client $sort', () async {
      service = MongoService(collection, allowQuery: false);
      expect(
        await titles({r'$sort': '-to', r'$limit': '1'}),
        unorderedEquals(['a', 'b', 'c']),
      );
    });

    test(r'$sort works over HTTP', () async {
      var app = Angel()..use('/api', service);
      var transport = AngelHttp(app);
      await transport.startServer('127.0.0.1', 0);
      addTearDown(transport.close);

      var response = await http.get(
        transport.uri.replace(path: '/api', query: r'$sort=-to&$limit=2'),
        headers: {'accept': 'application/json'},
      );
      var body = json.decode(response.body) as List;
      expect(body.map((d) => d['to']), ['c', 'b']);
    });
  });

  test('readMany returns only the given ids', () async {
    var a = await service.create({'to': 'a'});
    var b = await service.create({'to': 'b'});
    await service.create({'to': 'c'});
    var found = await service.readMany([a['id'], b['id']]);
    expect(found.map((d) => d['to']), unorderedEquals(['a', 'b']));
  });

  group('allowQuery: false', () {
    setUp(() => service = MongoService(collection, allowQuery: false));

    test('ignores a client query', () async {
      await service.create({'to': 'a'});
      await service.create({'to': 'b'});
      expect(await service.index(rest({'to': 'a'})), hasLength(2));
    });

    test('still applies a server-side query', () async {
      await service.create({'to': 'a'});
      await service.create({'to': 'b'});
      var found = await service.index({
        'query': {'to': 'a'},
      });
      expect(found.map((d) => d['to']), ['a']);
    });
  });

  test('a nested query map drops request-context keys at any depth', () async {
    await service.create({
      'meta': {
        'inner': {'k': 1},
      },
    });
    var found = await service.index(
      rest({
        'meta': {
          'inner': {'k': 1, '__requestctx': 'x'},
        },
      }),
    );
    expect(found, hasLength(1));
  });

  group('a malformed id is a 400', () {
    test('in read', () {
      expect(() => service.read('zzz'), throwsStatus(400));
    });
    test('in modify', () {
      expect(() => service.modify('zzz', {'to': 'b'}), throwsStatus(400));
    });
    test('in update', () {
      expect(() => service.update('zzz', {'to': 'b'}), throwsStatus(400));
    });
    test('in remove', () {
      expect(() => service.remove('zzz'), throwsStatus(400));
    });
  });

  group('modify', () {
    test('merges the data and stores no id field', () async {
      var created = await service.create({
        'to': 'a',
        'meta': {'k': 1},
      });
      var id = created['id'] as String;
      var result = await service.modify(id, {
        'id': 'other',
        'meta': {'j': 2},
      }, rest());
      expect(result['id'], id);
      expect(result['to'], 'a');
      expect(result['meta'], {'k': 1, 'j': 2});
      expect(result['createdAt'], created['createdAt']);

      var raw = (await collection.findOne(where.id(ObjectId.parse(id))))!;
      expect(raw.containsKey('id'), isFalse);
    });

    test('of a missing id is a 404 and changes nothing', () async {
      await service.create({'to': 'a'});
      await expectLater(
        () => service.modify(ObjectId().oid, {'to': 'b'}, rest()),
        throwsStatus(404),
      );
      var all = await service.index();
      expect(all.map((d) => d['to']), ['a']);
    });
  });

  group('update', () {
    test('replaces the document and keeps createdAt', () async {
      var created = await service.create({'to': 'a', 'extra': true});
      var id = created['id'] as String;
      var result = await service.update(id, {'id': 'other', 'to': 'b'});
      expect(result['id'], id);
      expect(result['to'], 'b');
      expect(result.containsKey('extra'), isFalse);
      expect(result['createdAt'], created['createdAt']);
    });

    test('of a missing id creates it with that id', () async {
      var id = ObjectId().oid;
      var result = await service.update(id, {'to': 'b'});
      expect(result['id'], id);
      expect((await service.read(id))['to'], 'b');
    });
  });

  group('remove', () {
    test('returns the removed document', () async {
      var created = await service.create({'to': 'a'});
      var removed = await service.remove(created['id'] as String);
      expect(removed['to'], 'a');
      expect(await collection.count(), 0);
    });

    test('of a missing id is a 404', () {
      expect(() => service.remove(ObjectId().oid), throwsStatus(404));
    });

    test('of "null" removes everything, server-side', () async {
      await service.create({'to': 'a'});
      await service.create({'to': 'b'});
      await service.remove('null');
      expect(await collection.count(), 0);
    });

    test('of "null" is forbidden to clients unless allowed', () async {
      await service.create({'to': 'a'});
      await expectLater(
        () => service.remove('null', rest()),
        throwsStatus(403),
      );
      expect(await collection.count(), 1);
    });
  });
}
