import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_rethinkdb/angel3_rethinkdb.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  late RethinkDb r;
  late Connection conn;
  late Angel app;
  late HookedService<String, Map<String, dynamic>, RethinkService> service;

  Matcher throwsStatus(int code) => throwsA(
    isA<AngelHttpException>().having((e) => e.statusCode, 'statusCode', code),
  );

  setUp(() async {
    r = RethinkDb();
    conn = await r.connect(
      db: 'testDB',
      host: rethinkHost,
      port: 28015,
      user: "admin",
      password: "",
    );
    await r.table('todos').delete().run(conn);
    app = Angel();
    service = app.use<String, Map<String, dynamic>, RethinkService>(
      '/todos',
      RethinkService(conn, r.table('todos')),
    );
  });

  tearDown(() async {
    await app.close();
    conn.close();
  });

  Future<String> insert(Map<String, dynamic> data) async =>
      (await service.create(data))['id'] as String;

  test('index returns typed maps', () async {
    await insert({'title': 'a'});
    await insert({'title': 'b'});
    var all = await service.index();
    expect(all, hasLength(2));
    expect(all.map((t) => t['title']), unorderedEquals(['a', 'b']));
  });

  test('index filters by a query map', () async {
    await insert({'title': 'a', 'completed': true});
    await insert({'title': 'b', 'completed': false});
    var done = await service.index({
      'query': {'completed': true},
    });
    expect(done.map((t) => t['title']), ['a']);
  });

  test('create with an id keeps it, and a duplicate id is a 409', () async {
    var created = await service.create({'id': 'fixed', 'title': 'a'});
    expect(created['id'], 'fixed');
    expect(
      () => service.create({'id': 'fixed', 'title': 'b'}),
      throwsStatus(409),
    );
  });

  test('read ignores the query, so query-string filters work', () async {
    var id = await insert({'title': 'a'});
    var found = await service.read(id, {
      'query': {'foo': 'bar'},
    });
    expect(found['title'], 'a');
  });

  test('read of a missing id is a 404', () {
    expect(() => service.read('missing'), throwsStatus(404));
  });

  test('modify changes the record in the path, not the body id', () async {
    var a = await insert({'title': 'a'});
    var result = await service.modify(a, {'id': 'other', 'title': 'b'});
    expect(result['id'], a);
    expect(result['title'], 'b');
    expect(await service.index(), hasLength(1));
  });

  test('modify of a missing id is a 404 and creates nothing', () async {
    await expectLater(
      () => service.modify('missing', {'title': 'b'}),
      throwsStatus(404),
    );
    expect(await service.index(), isEmpty);
  });

  test('update replaces the record in the path, not the body id', () async {
    var a = await insert({'title': 'a', 'completed': true});
    var result = await service.update(a, {'id': 'other', 'title': 'b'});
    expect(result, {'id': a, 'title': 'b'});
    expect(await service.index(), hasLength(1));
  });

  test('update of a missing id creates it with that id', () async {
    var result = await service.update('new-id', {'title': 'b'});
    expect(result, {'id': 'new-id', 'title': 'b'});
  });

  test('remove with a query only removes the given record', () async {
    var a = await insert({'title': 'a'});
    await insert({'title': 'b'});
    var removed = await service.remove(a, {'query': (RqlQuery t) => t});
    expect(removed['id'], a);
    expect((await service.index()).map((t) => t['title']), ['b']);
  });

  test('clients cannot remove everything unless allowed', () async {
    await insert({'title': 'a'});
    await expectLater(
      () => service.inner.remove(null, {'provider': Providers.rest}),
      throwsStatus(403),
    );
    expect(await service.index(), hasLength(1));
  });

  test('server-side remove(null) removes only matching records', () async {
    await insert({'title': 'a', 'completed': true});
    await insert({'title': 'b', 'completed': false});
    var result = await service.inner.remove(null, {
      'query': {'completed': true},
    });
    expect(result['deleted'], 1);
    expect((await service.index()).map((t) => t['title']), ['b']);
  });

  test('changefeed fires afterUpdated and afterRemoved', () async {
    var id = await insert({'title': 'a'});
    // Let the changefeed start.
    await Future.delayed(const Duration(milliseconds: 500));

    var created = <HookedServiceEvent>[];
    var updated = Completer<HookedServiceEvent>();
    var removed = Completer<HookedServiceEvent>();
    service.afterCreated.listen(created.add);
    service.afterUpdated.listen(updated.complete);
    service.afterRemoved.listen(removed.complete);

    await r.table('todos').get(id).update({'title': 'b'}).run(conn);
    var u = await updated.future.timeout(const Duration(seconds: 5));
    expect(u.id, id);
    expect(u.result['title'], 'b');

    await r.table('todos').get(id).delete().run(conn);
    var d = await removed.future.timeout(const Duration(seconds: 5));
    expect(d.id, id);

    expect(created, isEmpty);
  });

  group('over a query that is not a table', () {
    late RethinkService pending;

    setUp(() {
      pending = RethinkService(
        conn,
        r.table('todos').filter({'completed': false}),
        listenForChanges: false,
      );
    });

    test('reads, modifies and removes by id', () async {
      var id = await insert({'title': 'a', 'completed': false});
      expect((await pending.read(id))['title'], 'a');
      expect((await pending.modify(id, {'title': 'b'}))['title'], 'b');
      expect((await pending.remove(id))['title'], 'b');
      expect(await service.index(), isEmpty);
    });

    test('does not find records outside the query', () async {
      var id = await insert({'title': 'a', 'completed': true});
      expect(() => pending.read(id), throwsStatus(404));
    });
  });

  test('a REST client can index', () async {
    var client = await connectTo(app);
    addTearDown(client.close);
    await insert({'title': 'a'});
    expect(await client.service('todos').index(), hasLength(1));
  });
}
