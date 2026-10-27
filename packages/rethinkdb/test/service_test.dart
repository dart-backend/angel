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

  test('read of a missing id is a 404', () async {
    await expectLater(service.read('missing'), throwsStatus(404));
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

  group('an untyped callback', () {
    // (t) => ... is a dynamic Function(dynamic), not a QueryCallback.
    test('as query filters index', () async {
      await insert({'title': 'a', 'completed': true});
      await insert({'title': 'b', 'completed': false});
      var done = await service.index({
        'query': (t) => t.filter({'completed': true}),
      });
      expect(done.map((t) => t['title']), ['a']);
    });

    test('as reql extends the query', () async {
      // Inserted out of order, so that only the sort orders them.
      await insert({'title': 'b'});
      await insert({'title': 'c'});
      await insert({'title': 'a'});
      var sorted = await service.index({'reql': (q) => q.orderBy('title')});
      expect(sorted.map((t) => t['title']), ['a', 'b', 'c']);
    });

    test('as query makes server-side remove(null) remove only matching '
        'records', () async {
      await insert({'title': 'a', 'completed': true});
      await insert({'title': 'b', 'completed': false});
      var result = await service.inner.remove(null, {
        'query': (t) => t.filter({'completed': true}),
      });
      expect(result['deleted'], 1);
      expect((await service.index()).map((t) => t['title']), ['b']);
    });

    test('that does not return a query is an ArgumentError', () async {
      await expectLater(
        service.index({'query': (t) => 'not a query'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test(
    'changefeed fires afterCreated, afterUpdated and afterRemoved',
    () async {
      await service.inner.changefeedStarted;

      var created = <HookedServiceEvent>[];
      var updated = Completer<HookedServiceEvent>();
      var removed = Completer<HookedServiceEvent>();
      service.afterCreated.listen(created.add);
      service.afterUpdated.listen(updated.complete);
      service.afterRemoved.listen(removed.complete);

      // Written to RethinkDB directly, so the events come from the changefeed.
      var id = 'feed';
      await r.table('todos').insert({'id': id, 'title': 'a'}).run(conn);
      await r.table('todos').get(id).update({'title': 'b'}).run(conn);
      var u = await updated.future.timeout(const Duration(seconds: 5));
      expect(u.id, id);
      expect(u.result['title'], 'b');

      await r.table('todos').get(id).delete().run(conn);
      var d = await removed.future.timeout(const Duration(seconds: 5));
      expect(d.id, id);

      // The update and the removal are not reported as creations.
      expect(created.map((e) => e.id), [id]);
    },
  );

  test('a changefeed starting when the service closes is stopped', () async {
    // Its own connection, whose changefeeds the server lists as jobs.
    var own = await r.connect(
      db: 'testDB',
      host: rethinkHost,
      port: 28015,
      user: "admin",
      password: "",
    );
    addTearDown(own.close);
    Future<int> changefeeds() async {
      var jobs =
          await (await r.db('rethinkdb').table('jobs').run(own) as Cursor)
              .toList();
      // The server sees the port of the connection as the one this query of
      // the jobs comes from; forwarding to a container can change it.
      var port = jobs.firstWhere(
        (j) => '${j['info']['query']}'.contains('"jobs"'),
      )['info']['client_port'];
      return jobs
          .where(
            (j) =>
                j['info']['client_port'] == port &&
                '${j['info']['query']}'.contains('changes'),
          )
          .length;
    }

    var closing = Angel();
    var hooked = closing.use<String, Map<String, dynamic>, RethinkService>(
      '/todos',
      RethinkService(own, r.table('todos')),
    );
    addTearDown(closing.close);
    // Closed at once, before the changefeed has started.
    hooked.inner.close();
    await hooked.inner.changefeedStarted;
    await Future.delayed(const Duration(milliseconds: 300));
    expect(await changefeeds(), 0);
  });

  test('a changefeed over a single record fires its changes', () async {
    var id = await insert({'title': 'a'});
    var single = Angel();
    addTearDown(single.close);
    var hooked = single.use<String, Map<String, dynamic>, RethinkService>(
      '/todo',
      RethinkService(conn, r.table('todos').get(id)),
    );
    await hooked.inner.changefeedStarted;
    var updated = Completer<HookedServiceEvent>();
    hooked.afterUpdated.listen(updated.complete);

    await r.table('todos').get(id).update({'title': 'b'}).run(conn);
    var u = await updated.future.timeout(const Duration(seconds: 5));
    expect(u.result['title'], 'b');
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
      await expectLater(pending.read(id), throwsStatus(404));
    });

    test('modify that moves a record out of the query returns it', () async {
      var id = await insert({'title': 'a', 'completed': false});
      var result = await pending.modify(id, {'completed': true});
      expect(result['id'], id);
      expect(result['completed'], isTrue);
    });

    test('update that moves a record out of the query returns it', () async {
      var id = await insert({'title': 'a', 'completed': false});
      var result = await pending.update(id, {'title': 'b'});
      expect(result, {'id': id, 'title': 'b'});
    });

    test('modify that changes nothing returns the record', () async {
      var id = await insert({'title': 'a', 'completed': false});
      var result = await pending.modify(id, {'title': 'a'});
      expect(result['title'], 'a');
    });
  });

  test('a REST client can index', () async {
    var client = await connectTo(app);
    addTearDown(client.close);
    await insert({'title': 'a'});
    expect(await client.service('todos').index(), hasLength(1));
  });
}
