import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';

/// A `PostgreSqlExecutor` whose connection the server ends, as when the
/// database restarts.
void main() {
  final settings = ConnectionSettings(sslMode: SslMode.disable);

  /// A connection apart from the executor's, which ends it and counts the
  /// connections to the server.
  late Connection admin;

  setUp(() async {
    admin = await openPgConnection();
    addTearDown(admin.close);
  });

  /// The connections of clients to the server, [admin]'s included.
  Future<int> connections() async =>
      (await admin.execute(
            "SELECT count(*) FROM pg_stat_activity "
            "WHERE backend_type = 'client backend'",
          )).first.first
          as int;

  /// Expects [expected] connections, once the server has seen those that
  /// were opened or closed.
  Future<void> expectConnections(int expected) async {
    var count = await connections();
    for (var i = 0; i < 20 && count != expected; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      count = await connections();
    }
    expect(count, expected);
  }

  PostgreSqlExecutor executorWithEndpoint(Connection connection) {
    var executor = PostgreSqlExecutor(
      connection,
      endpoint: pgEndpoint(),
      settings: settings,
    );
    addTearDown(executor.close);
    return executor;
  }

  /// Ends [executor]'s connection on the server.
  Future<void> breakConnection(PostgreSqlExecutor executor) async {
    var connection = executor.session as Connection;
    var pid = (await executor.query(
      'x',
      'SELECT pg_backend_pid()',
      {},
    )).first.first;
    await admin.execute('SELECT pg_terminate_backend($pid)');
    // Until the client sees that the server closed it.
    for (var i = 0; i < 50 && connection.isOpen; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  test('with its endpoint, opens one new connection for the queries that '
      'fail on the broken one', () async {
    var executor = executorWithEndpoint(
      await Connection.open(pgEndpoint(), settings: settings),
    );
    var broken = executor.session;
    // The executor's and admin's.
    var before = await connections();
    await breakConnection(executor);

    var results = await Future.wait([
      executor.query('x', 'SELECT 1', {}),
      executor.query('x', 'SELECT 2', {}),
      executor.query('x', 'SELECT 3', {}),
    ]);
    expect([for (var r in results) r.first.first], [1, 2, 3]);
    expect(executor.session, isNot(same(broken)));
    // One replaced the broken one: none was opened for each query.
    await expectConnections(before);
  });

  test('with its endpoint, runs a transaction on a new connection', () async {
    var executor = executorWithEndpoint(
      await Connection.open(pgEndpoint(), settings: settings),
    );
    var broken = executor.session;
    await breakConnection(executor);

    var result = await executor.transaction(
      (tx) async => (await tx.query('x', 'SELECT 1', {})).first.first,
    );
    expect(result, 1);
    expect(executor.session, isNot(same(broken)));
  });

  test('with its endpoint, throws the error of a query the connection broke '
      'during, and runs the next one on a new connection', () async {
    var executor = executorWithEndpoint(
      await Connection.open(pgEndpoint(), settings: settings),
    );
    var pid = (await executor.query(
      'x',
      'SELECT pg_backend_pid()',
      {},
    )).first.first;

    // Sent, so not sent again, as it may have run.
    var sleeping = executor.query('x', 'SELECT pg_sleep(5)', {});
    await Future.delayed(const Duration(milliseconds: 300));
    await admin.execute('SELECT pg_terminate_backend($pid)');
    await expectLater(sleeping, throwsA(isA<PgException>()));

    expect((await executor.query('x', 'SELECT 1', {})).first.first, 1);
  });

  test('after close, opens no new connection', () async {
    var executor = executorWithEndpoint(
      await Connection.open(pgEndpoint(), settings: settings),
    );
    var before = await connections();

    await executor.close();
    await expectLater(executor.query('x', 'SELECT 1', {}), throwsA(anything));
    await expectLater(
      executor.transaction((tx) => tx.query('x', 'SELECT 1', {})),
      throwsA(anything),
    );
    await expectConnections(before - 1);
  });

  test(
    'without an endpoint, throws the error of the broken connection',
    () async {
      var connection = await Connection.open(pgEndpoint(), settings: settings);
      var executor = PostgreSqlExecutor(connection);
      addTearDown(executor.close);
      await breakConnection(executor);

      await expectLater(
        executor.query('x', 'SELECT 1', {}),
        throwsA(
          isA<PgException>().having(
            (e) => e.message,
            'message',
            contains('connection is not open'),
          ),
        ),
      );
      expect(executor.session, same(connection));
    },
  );

  test('without an endpoint, warns once of the broken connection', () async {
    var logger = Logger.detached('PostgreSqlExecutor')..level = Level.ALL;
    var warnings = <String>[];
    logger.onRecord
        .where((r) => r.level == Level.WARNING)
        .listen((r) => warnings.add(r.message));
    var executor = PostgreSqlExecutor(
      await Connection.open(pgEndpoint(), settings: settings),
      logger: logger,
    );
    addTearDown(executor.close);
    await breakConnection(executor);

    for (var i = 0; i < 3; i++) {
      await expectLater(
        executor.query('x', 'SELECT 1', {}),
        throwsA(isA<PgException>()),
      );
    }
    expect(
      warnings.where((w) => w.contains('cannot be replaced')),
      hasLength(1),
    );
  });
}
