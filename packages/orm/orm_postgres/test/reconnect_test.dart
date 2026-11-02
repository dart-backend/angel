import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';

/// A `PostgreSqlExecutor` whose connection the server ends, as when the
/// database restarts.
void main() {
  final settings = ConnectionSettings(sslMode: SslMode.disable);

  /// Ends [executor]'s connection on the server.
  Future<void> breakConnection(PostgreSqlExecutor executor) async {
    var pid = (await executor.query(
      'x',
      'SELECT pg_backend_pid()',
      {},
    )).first.first;
    var admin = await openPgConnection();
    addTearDown(admin.close);
    await admin.execute('SELECT pg_terminate_backend($pid)');
    // Until the client sees that the server closed it.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  test('with its endpoint, opens one new connection for the queries that '
      'fail on the broken one', () async {
    var executor = PostgreSqlExecutor(
      await Connection.open(pgEndpoint(), settings: settings),
      endpoint: pgEndpoint(),
      settings: settings,
    );
    addTearDown(executor.close);
    var broken = executor.session;
    await breakConnection(executor);

    var results = await Future.wait([
      executor.query('x', 'SELECT 1', {}),
      executor.query('x', 'SELECT 2', {}),
    ]);
    expect([for (var r in results) r.first.first], [1, 2]);
    expect(executor.session, isNot(same(broken)));
    expect((await executor.query('x', 'SELECT 3', {})).first.first, 3);
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
}
