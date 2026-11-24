import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:angel3_orm_service/angel3_orm_service.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'uuid_user.dart';

const ana = '6f1c2a8e-3b4d-4e5f-8a9b-0c1d2e3f4a5b';
const bo = '7a2d3b9f-4c5e-4f6a-9b0c-1d2e3f4a5b6c';
const cy = '8b3e4c0a-5d6f-4a7b-8c1d-2e3f4a5b6c7d';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Whether [id] is a UUID, as a `validateId` of an app.
bool isUuid(Object id) => _uuid.hasMatch('$id');

/// Throws an [AngelHttpException] of [status].
Matcher throwsHttp(int status) => throwsA(
  isA<AngelHttpException>().having((e) => e.statusCode, 'statusCode', status),
);

/// An [OrmService] of a `Model` whose `id` is a UUID, which `copyFrom` sets,
/// as the database does not generate it.
void main() {
  late PostgreSqlExecutor executor;
  late OrmService<String?, UuidUser, UuidUserQuery> service;

  setUp(() async {
    var conn = await openPgConnection();
    executor = PostgreSqlExecutor(conn);
    await conn.execute('''
    CREATE TEMPORARY TABLE uuid_users (
      id uuid PRIMARY KEY,
      name varchar,
      created_at timestamp,
      updated_at timestamp
    );
    ''');
    service = OrmService(executor, () => UuidUserQuery());
    await service.create(UuidUser(id: ana, name: 'Ana'));
    await service.create(UuidUser(id: bo, name: 'Bo'));
  });

  tearDown(() async {
    await executor.close();
    service.close();
  });

  Future<Map<String?, String?>> all() async => {
    for (var u in await service.index()) u.id: u.name,
  };

  test('create keeps the id given', () async {
    var created = await service.create(UuidUser(id: cy, name: 'Cy'));
    expect(created.id, cy);
    expect(created.name, 'Cy');
  });

  test('read, readMany and a query by id', () async {
    expect((await service.read(bo)).name, 'Bo');
    expect((await service.readMany([ana, bo, cy])).map((u) => u.id).toSet(), {
      ana,
      bo,
    });
    var found = await service.index({
      'query': {'id': ana},
    });
    expect(found.map((u) => u.name), ['Ana']);
  });

  test('remove', () async {
    expect((await service.remove(ana)).id, ana);
    expect(await all(), {bo: 'Bo'});
  });

  test('update of data without an id keeps the id', () async {
    var updated = await service.update(ana, UuidUser(name: 'Ana Maria'));
    expect(updated.id, ana);
    expect(updated.name, 'Ana Maria');
    expect(await all(), {ana: 'Ana Maria', bo: 'Bo'});
  });

  test('update of data of another id does not change the key', () async {
    var updated = await service.update(ana, UuidUser(id: cy, name: 'Ana M.'));
    expect(updated.id, ana);
    expect(await all(), {ana: 'Ana M.', bo: 'Bo'});
  });

  test('modify of data of another id does not change the key', () async {
    var modified = await service.modify(ana, UuidUser(id: cy, name: 'A.'));
    expect(modified.id, ana);
    expect(await all(), {ana: 'A.', bo: 'Bo'});
  });

  test('modify of only an id changes nothing', () async {
    var modified = await service.modify(ana, UuidUser(id: cy));
    expect(modified.id, ana);
    expect(await all(), {ana: 'Ana', bo: 'Bo'});
  });

  test(
    'create without an id is a 400, as the database does not give one',
    () async {
      expect(() => service.create(UuidUser(name: 'Cy')), throwsHttp(400));
      expect(await all(), {ana: 'Ana', bo: 'Bo'});
    },
  );

  group('validateId', () {
    late OrmService<String?, UuidUser, UuidUserQuery> checked;

    setUp(() {
      checked = OrmService(executor, () => UuidUserQuery(), validateId: isUuid);
    });

    test('an id it refuses is a 404 of a lookup, not a query', () async {
      expect(() => checked.read('not-a-uuid'), throwsHttp(404));
      expect(
        () => checked.update('not-a-uuid', UuidUser(name: 'X')),
        throwsHttp(404),
      );
      expect(
        () => checked.modify('not-a-uuid', UuidUser(name: 'X')),
        throwsHttp(404),
      );
      expect(() => checked.remove('not-a-uuid'), throwsHttp(404));
      expect(await all(), {ana: 'Ana', bo: 'Bo'});
    });

    test('readMany leaves it out', () async {
      expect((await checked.readMany(['not-a-uuid', ana])).map((u) => u.id), [
        ana,
      ]);
      expect(await checked.readMany(['not-a-uuid']), isEmpty);
    });

    test('of a query, or of create, is a 400', () async {
      expect(
        () => checked.index({
          'query': {'id': 'not-a-uuid'},
        }),
        throwsHttp(400),
      );
      expect(
        () => checked.create(UuidUser(id: 'not-a-uuid', name: 'X')),
        throwsHttp(400),
      );
    });

    test('an id it takes is queried', () async {
      expect((await checked.read(ana)).name, 'Ana');
      expect(() => checked.read(cy), throwsHttp(404));
    });

    test('without it, PostgreSQL refuses a malformed UUID itself', () async {
      expect(
        () => service.read('not-a-uuid'),
        throwsA(isNot(isA<AngelHttpException>())),
      );
    });
  });
}
