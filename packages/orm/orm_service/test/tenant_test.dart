import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:angel3_orm_service/angel3_orm_service.dart';
import 'package:angel3_orm_sqlite/angel3_orm_sqlite.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'pokemon.dart';

/// Throws an [AngelHttpException] of [status].
Matcher throwsHttp(int status) => throwsA(
  isA<AngelHttpException>().having((e) => e.statusCode, 'statusCode', status),
);

/// The database of a tenant: its [executor], and [close], which drops its
/// table and closes it.
typedef Tenant = ({QueryExecutor executor, Future<void> Function() close});

/// A database of the tests, which opens the database of a tenant of its
/// name, with a `pokemons` table whose `name` is unique if `uniqueNames`.
class Backend {
  final String name;
  final Future<Tenant> Function(String database, {bool uniqueNames}) open;

  const Backend(this.name, this.open);
}

/// The databases of the tenants `a` and `b`, of `TENANT_DATABASES`, by
/// default `tenant_a,tenant_b`, which the server must have, and the test's
/// user be able to create tables in. SQLite opens them in memory.
final _databases =
    (Platform.environment['TENANT_DATABASES'] ?? 'tenant_a,tenant_b').split(
      ',',
    );

/// The backends to run the tests on, of `TENANT_BACKENDS`: by default
/// `sqlite` only, as the others need a server, of the `POSTGRES_*` and
/// `MYSQL_*` variables of the other tests.
final _enabled = (Platform.environment['TENANT_BACKENDS'] ?? 'sqlite').split(
  ',',
);

final _backends = [
  Backend('sqlite', (database, {uniqueNames = false}) async {
    var db = sqlite3.openInMemory()
      ..execute('''
      CREATE TABLE pokemons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        species TEXT, name TEXT, level INTEGER, type1 INTEGER, type2 INTEGER,
        created_at TEXT, updated_at TEXT
      );
      ''');
    if (uniqueNames) {
      db.execute('CREATE UNIQUE INDEX names ON pokemons (name);');
    }
    var executor = SqliteExecutor(db);
    return (executor: executor, close: executor.close);
  }),
  Backend('postgres', (database, {uniqueNames = false}) async {
    var conn = await openPgConnection(database: database);
    await conn.execute('DROP TABLE IF EXISTS pokemons');
    await conn.execute('''
      CREATE TABLE pokemons (
        id serial PRIMARY KEY,
        species varchar, name varchar, level integer, type1 integer,
        type2 integer, created_at timestamp, updated_at timestamp
      );
      ''');
    if (uniqueNames) {
      await conn.execute('CREATE UNIQUE INDEX names ON pokemons (name)');
    }
    var executor = PostgreSqlExecutor(conn);
    return (
      executor: executor as QueryExecutor,
      close: () async {
        await conn.execute('DROP TABLE IF EXISTS pokemons');
        await executor.close();
      },
    );
  }),
  Backend('mariadb', (database, {uniqueNames = false}) async {
    var env = Platform.environment;
    var conn = await MySQLConnection.createConnection(
      databaseName: database,
      host: env['MYSQL_HOST'] ?? 'localhost',
      port: int.parse(env['MYSQL_PORT'] ?? '3306'),
      userName: env['MYSQL_USERNAME'] ?? 'test',
      password: env['MYSQL_PASSWORD'] ?? 'Test123',
      secure: env['MYSQL_SECURE'] != 'false',
    );
    await conn.connect(timeoutMs: 10000);
    await conn.execute('DROP TABLE IF EXISTS pokemons');
    await conn.execute('''
      CREATE TABLE pokemons (
        id INT AUTO_INCREMENT PRIMARY KEY,
        species VARCHAR(255), name VARCHAR(255), level INT, type1 INT,
        type2 INT, created_at DATETIME(6), updated_at DATETIME(6)
      );
      ''');
    if (uniqueNames) {
      await conn.execute('CREATE UNIQUE INDEX names ON pokemons (name)');
    }
    var executor = MariaDbExecutor(conn);
    return (
      executor: executor as QueryExecutor,
      close: () async {
        await conn.execute('DROP TABLE IF EXISTS pokemons');
        await executor.close();
      },
    );
  }),
];

/// An [OrmService] of [OrmService.of], whose executor is the database of the
/// tenant of each call, of its params (issue 151): a database of each
/// tenant, of each backend.
void main() {
  for (var backend in _backends) {
    group(
      backend.name,
      () => _tests(backend),
      skip: _enabled.contains(backend.name)
          ? false
          : 'Not in TENANT_BACKENDS (${_enabled.join(',')})',
    );
  }
}

void _tests(Backend backend) {
  late Map<String, Tenant> tenants;
  // The tenant of each call of the service's executorOf.
  var resolved = <Object?>[];
  late OrmService<int?, Pokemon, PokemonQuery> service;

  Pokemon pikachu([String name = 'Sparky']) => Pokemon(
    species: 'Pikachu',
    name: name,
    level: 5,
    type1: PokemonType.electric,
  );

  Map<String, dynamic> of(String tenant) => {'tenant': tenant};

  setUp(() async {
    tenants = {
      'a': await backend.open(_databases[0]),
      'b': await backend.open(_databases[1], uniqueNames: true),
    };
    resolved.clear();
    service = OrmService.of(
      (params) {
        var tenant = params?['tenant'];
        resolved.add(tenant);
        return tenants[tenant]?.executor ??
            (throw AngelHttpException.notFound(message: 'No such tenant.'));
      },
      () => PokemonQuery(),
      // As of a key that is a positive integer.
      validateId: (id) => (id is int ? id : int.tryParse('$id') ?? 0) > 0,
    );
  });

  tearDown(() async {
    service.close();
    for (var tenant in tenants.values) {
      await tenant.close();
    }
  });

  test('each tenant reads and writes its own database', () async {
    var created = await service.create(pikachu(), of('a'));
    expect((await service.index(of('a'))).map((p) => p.name), ['Sparky']);
    expect(await service.index(of('b')), isEmpty);
    expect(await service.read(int.parse(created.id!), of('a')), created);
    expect(service.read(int.parse(created.id!), of('b')), throwsHttp(404));
    expect(service.remove(int.parse(created.id!), of('b')), throwsHttp(404));
    expect(await service.index(of('a')), hasLength(1));
  });

  test('resolves the executor once of each call', () async {
    var id = int.parse((await service.create(pikachu(), of('a'))).id!);
    await service.index(of('a'));
    await service.read(id, of('a'));
    await service.readMany([id], of('a'));
    await service.findOne(of('a'));
    await service.update(id, pikachu('Volt'), of('a'));
    await service.modify(
      id,
      Pokemon(species: null, level: 6, type1: null),
      of('a'),
    );
    // Nothing to change: the record is read, once.
    await service.modify(
      id,
      Pokemon(species: null, level: null, type1: null),
      of('a'),
    );
    await service.remove(id, of('a'));
    expect(resolved, List.filled(9, 'a'));
  });

  test('checks the ids of a call before its executor', () async {
    // The tenant is not one, but the id cannot be a record's.
    expect(service.read(-1, of('none')), throwsHttp(404));
    expect(service.update(-1, pikachu(), of('none')), throwsHttp(404));
    expect(service.modify(-1, pikachu(), of('none')), throwsHttp(404));
    expect(service.remove(-1, of('none')), throwsHttp(404));
    expect(await service.readMany([-1], of('none')), isEmpty);
    expect(
      service.index({
        'tenant': 'none',
        'query': {'id': -1},
      }),
      throwsHttp(400),
    );
    await pumpEventQueue();
    expect(resolved, isEmpty);
  });

  test('throws the error of executorOf, as of an unknown tenant', () async {
    expect(service.index(of('none')), throwsHttp(404));
    expect(service.create(pikachu(), of('none')), throwsHttp(404));
    expect(service.index(), throwsHttp(404));
  });

  test('classifies an error of the database of the call', () async {
    // Only the database of b has unique names.
    await service.create(pikachu(), of('a'));
    await service.create(pikachu(), of('a'));
    await service.create(pikachu(), of('b'));
    expect(service.create(pikachu(), of('b')), throwsHttp(409));
  });

  test('has no executor of its own', () {
    expect(() => service.executor.query('pokemons', '', {}), throwsStateError);
    expect(() => service.executor.dialect, throwsStateError);
  });

  group('over HTTP', () {
    late Angel app;

    setUp(() async {
      app = Angel();
      // The tenant of the request, as an app's middleware would tell it of
      // the request's user; a client cannot set a service's params.
      app.fallback((req, res) {
        req.serviceParams['tenant'] = req.headers?.value('x-tenant');
        return true;
      });
      app.use('/pokemon', service);
      await service.create(pikachu('InA'), of('a'));
      await service.create(pikachu('InB'), of('b'));
    });

    Future<MockHttpResponse> get(String path, String tenant) async {
      var rq = MockHttpRequest('GET', Uri.parse(path))
        ..headers.set('x-tenant', tenant);
      await rq.close();
      await AngelHttp(app).handleRequest(rq);
      return rq.response;
    }

    Future<Object?> body(MockHttpResponse response) async =>
        json.decode(await response.transform(utf8.decoder).join());

    test('reads the database of the tenant of the request', () async {
      var response = await get('/pokemon', 'b');
      expect(response.statusCode, 200);
      expect((await body(response) as List).map((p) => p['name']), ['InB']);
    });

    test('a query parameter cannot choose the tenant', () async {
      // A client's query is of the query's columns, under `query` of the
      // params: `tenant` is not one, so it is a 400, before any executor.
      resolved.clear();
      var response = await get('/pokemon?tenant=b', 'a');
      expect(response.statusCode, 400);
      expect(resolved, isEmpty);
      // A filter of a column is of the tenant of the request.
      response = await get('/pokemon?name=InB', 'a');
      expect(response.statusCode, 200);
      expect(await body(response), isEmpty);
      expect(resolved, ['a']);
    });

    test('is a 404 of a tenant that is not one', () async {
      expect((await get('/pokemon', 'none')).statusCode, 404);
    });
  });

  test('a service of an executor is as before', () async {
    var plain = OrmService<int?, Pokemon, PokemonQuery>(
      tenants['a']!.executor,
      () => PokemonQuery(),
    );
    expect(plain.executorOf, isNull);
    await plain.create(pikachu());
    expect(await plain.index(), hasLength(1));
    expect(await service.index(of('a')), hasLength(1));
    plain.close();
  });
}
