import 'dart:collection';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_sembast/angel3_sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() async {
  late Database database;
  late SembastService service;

  setUp(() async {
    // A new database for each test, so that none sees the records of another.
    database = await newDatabaseFactoryMemory().openDatabase('test.db');
    service = SembastService(database);
  });

  tearDown(() => database.close());

  test('index', () async {
    await service.create({'id': '0', 'name': 'Tobe'});
    await service.create({'id': '1', 'name': 'Osakwe'});

    var output = await service.index();
    print(output);
    expect(output, hasLength(2));
    expect(output[0], <String, dynamic>{'id': '1', 'name': 'Tobe'});
    expect(output[1], <String, dynamic>{'id': '2', 'name': 'Osakwe'});
  });

  test('create', () async {
    var input = {'bar': 'baz'};
    var output = await service.create(input);
    print(output);
    expect(output.keys, contains('id'));
    expect(output, containsPair('bar', 'baz'));
  });

  test('read', () async {
    var name = 'poobah${DateTime.now().millisecondsSinceEpoch}';
    var input = await service.create({'name': name, 'bar': 'baz'});
    print(input);
    expect(await service.read(input['id'] as String), input);
  });

  test('modify', () async {
    var input = await service.create({'bar': 'baz', 'yes': 'no'});
    var id = input['id'] as String;
    var output = await service.modify(id, {'bar': 'quux'});
    expect(
      SplayTreeMap.from(output),
      SplayTreeMap.from({'id': id, 'bar': 'quux', 'yes': 'no'}),
    );
    expect(await service.read(id), output);
  });

  test('update', () async {
    var input = await service.create({'bar': 'baz'});
    var id = input['id'] as String;
    var output = await service.update(id, {'yes': 'no'});
    expect(output, {'id': id, 'yes': 'no'});
    expect(await service.read(id), output);
  });

  test('remove', () async {
    var input = await service.create({'bar': 'baz'});
    var id = input['id'] as String?;
    expect(await service.remove(id), input);
    expect(await service.store.record(int.parse(id!)).get(database), isNull);
  });

  test('remove all', () async {
    await service.create({'bar': 'baz'});
    await service.create({'bar': 'baz'});
    await service.create({'bar': 'baz'});

    expect(await service.index(), isNotEmpty);
    await service.remove(null);
    expect(await service.index(), isEmpty);
  });

  test('cannot remove all unless explicitly set', () async {
    expect(
      () => service.remove(null, {'provider': Providers.rest}),
      throwsA(const TypeMatcher<AngelHttpException>()),
    );
    expect(
      () => service.remove(null, {'provider': Providers.rest}),
      throwsA(
        predicate(
          (dynamic x) => x is AngelHttpException && x.statusCode == 403,
          'throws forbidden',
        ),
      ),
    );
    expect(
      () => service.remove('null', {'provider': Providers.rest}),
      throwsA(const TypeMatcher<AngelHttpException>()),
    );
    expect(
      () => service.remove('null', {'provider': Providers.rest}),
      throwsA(
        predicate(
          (dynamic x) => x is AngelHttpException && x.statusCode == 403,
          'throws forbidden',
        ),
      ),
    );
  });

  test('can remove all on server side', () async {
    await service.create({'bar': 'baz'});
    await service.create({'bar': 'baz'});
    await service.create({'bar': 'baz'});
    await service.remove(null);
    expect(await service.index(), isEmpty);

    await service.create({'bar': 'baz'});
    await service.create({'bar': 'baz'});
    await service.create({'bar': 'baz'});
    await service.remove('null');
    expect(await service.index(), isEmpty);
  });

  test('remove nonexistent', () async {
    expect(
      () => service.remove('440'),
      throwsA(const TypeMatcher<AngelHttpException>()),
    );
  });

  test('a stored id is the key of the record', () async {
    var created = await service.create({'id': '0', 'name': 'Tobe'});
    expect(created['id'], '1');
    expect(await service.read('1'), {'id': '1', 'name': 'Tobe'});
    expect(
      await service.index({
        'query': {'id': '1'},
      }),
      hasLength(1),
    );
    expect(
      await service.index({
        'query': {'id': '0'},
      }),
      isEmpty,
    );
  });

  group('query', () {
    setUp(() async {
      await service.create({'name': 'b', 'user': 1, 'done': true});
      await service.create({'name': 'a', 'user': 1, 'done': false});
      await service.create({'name': 'c', 'user': 2, 'done': true});
    });

    List<Object?> names(List<Map<String, dynamic>> records) => [
      for (var r in records) r['name'],
    ];

    test('matches every field', () async {
      var output = await service.index({
        'query': {'user': 1, 'done': true},
      });
      expect(names(output), ['b']);
    });

    test(r'$sort of -1 is descending, and 1 ascending', () async {
      expect(
        names(
          await service.index({
            r'$sort': {'name': -1},
          }),
        ),
        ['c', 'b', 'a'],
      );
      expect(
        names(
          await service.index({
            r'$sort': {'name': '1'},
          }),
        ),
        ['a', 'b', 'c'],
      );
    });

    test(r'$sort in the query of a request sorts', () async {
      var output = await service.index({
        'provider': Providers.rest,
        'query': {r'$sort': 'name', 'done': true},
      });
      expect(names(output), ['b', 'c']);
    });

    test('findOne returns the record with its id', () async {
      expect(
        await service.findOne({
          'query': {'name': 'a'},
        }),
        {'id': '2', 'name': 'a', 'user': 1, 'done': false},
      );
    });

    test('findOne of no record is a 404', () async {
      await expectLater(
        service.findOne({
          'query': {'name': 'missing'},
        }),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('remove all removes only the records of the query', () async {
      await service.remove(null, {
        'query': {'done': true},
      });
      expect(names(await service.index()), ['a']);
    });
  });

  test('modify and update of a nonexistent id are a 404', () async {
    for (var call in [
      () => service.modify('440', {'bar': 'x'}),
      () => service.update('440', {'bar': 'x'}),
    ]) {
      await expectLater(
        call(),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    }
    expect(await service.index(), isEmpty);
  });
}
