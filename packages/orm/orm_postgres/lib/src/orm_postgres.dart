import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import 'logging.dart';

import 'parameters.dart';

/// What the driver throws for values that its query does not use, before it
/// sends the query, with their names.
final RegExp _superfluousValues = RegExp(
  r'^Contains superfluous variables: (.+)$',
);

/// Runs [query] on [session], with the values of [parameters] it uses.
///
/// The driver rejects any other. The ORM gives none of its own, so these are of
/// a [QueryWhere.raw] or set by hand, such as one named only in a comment. The
/// driver knows which those are, as it reads
/// the SQL as it sends it, so they are left out by what it says: not by
/// reading the SQL a second time, which may differ, such as in a comment or a
/// dollar-quoted string. It sends nothing before it rejects them, so that this
/// is safe in a transaction.
Future<Result> _execute(
  Session session,
  String query,
  Map<String, dynamic> parameters,
) async {
  try {
    return await session.execute(Sql.named(query), parameters: parameters);
  } on ArgumentError catch (err) {
    var superfluous = _superfluousValues.firstMatch('${err.message}');
    if (superfluous == null) rethrow;
    var unused = superfluous[1]!.split(', ').toSet();
    return session.execute(
      Sql.named(query),
      parameters: {
        for (var MapEntry(:key, :value) in parameters.entries)
          if (!unused.contains(key)) key: value,
      },
    );
  }
}

/// A [QueryExecutor] that queries a PostgreSQL database.
class PostgreSqlExecutor extends QueryExecutor {
  final Dialect _dialect = const PostgreSQLDialect();

  ConnectionSettings? _settings;
  Endpoint? _endpoint;

  Session _session;

  /// The key of the savepoint a zone runs in, as a [_SavepointLevel].
  static final Object _savepointLevel = Object();

  /// For each transaction, the end of the last savepoint at each level of
  /// nesting, from 1, after which the next one at that level starts:
  /// savepoints form a stack, so two at a time at one level would roll back,
  /// or release, each other. One nested in another takes the next level, so
  /// it does not wait for the one it is in.
  static final Expando<Map<int, Future<void>>> _lastSavepointsOf = Expando();

  /// For each transaction, how many savepoints it has started, which names
  /// each one apart from the others.
  static final Expando<int> _savepointCountOf = Expando();

  /// An optional [Logger] to print information to. A default logger will be used
  /// if not set
  late Logger logger;

  @override
  Dialect get dialect => _dialect;

  /// The underlying database session.
  Session get session => _session;

  /// Runs queries on [_session]. With the [endpoint] and [settings] it was
  /// opened with, a [Connection] that breaks, as when the database restarts,
  /// is replaced by a new one; without them, its queries fail until the
  /// executor is replaced.
  PostgreSqlExecutor(
    this._session, {
    Endpoint? endpoint,
    ConnectionSettings? settings,
    Logger? logger,
  }) {
    this.logger = logger ?? Logger('PostgreSqlExecutor');

    _settings = settings;
    _endpoint = endpoint;
  }

  /// Whether [close] was called: the executor then opens no new connection.
  bool _closed = false;

  /// The broken connection the executor warned of, as it has no endpoint to
  /// replace it with.
  Connection? _warnedBroken;

  /// Closes the connection. The executor opens no new one after it, and one
  /// it is opening, to replace a broken connection, is closed once opened.
  Future<void> close() async {
    _closed = true;
    if (_session is Connection) {
      await (_session as Connection).close();
    }
  }

  @override
  Future<Result> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) async {
    logger.fine(() => 'Query: $query');
    // In debug mode only, as they may be passwords or personal data.
    logValues(logger, substitutionValues);

    var param = encodeParameters(substitutionValues);

    // The session the query runs on, which another query may replace: a
    // connection that broke, as during an earlier query, is replaced first.
    var session = await _openSession();
    try {
      return await _execute(session, query, param);
    } catch (err, st) {
      // Fine, as the error is thrown to the caller, who may expect it, as a
      // unique violation, and decides whether it is one to warn of.
      logError(logger, Level.FINE, 'The query failed', err, st);
      // The query was not sent, as the connection was found closed on
      // sending it: it is sent again, on a new connection. A query that was
      // sent is not, as it may have run; the next one replaces the connection.
      if (err is PgException &&
          err.message.contains("connection is not open") &&
          session is Connection) {
        if (_endpoint == null) {
          // Once for the connection, not for each query that fails on it.
          if (!identical(_warnedBroken, session)) {
            _warnedBroken = session;
            logger.warning(
              'The database connection is broken, and cannot be replaced, as '
              'the executor was given no endpoint.',
            );
          }
        } else if (!_closed) {
          var retry = identical(_session, session)
              ? await (_reconnecting ??= _reconnect(session))
              : _session;
          return await _execute(retry, query, param);
        }
      }
      rethrow;
    }
  }

  /// The session to run on: the current one or, when it is a connection that
  /// broke, as when the database restarted, and an endpoint was given, a new
  /// one that replaces it, shared by the queries and transactions that need
  /// one at the same time, so that none is opened in vain.
  Future<Session> _openSession() async {
    var session = _session;
    if (session is Connection &&
        !session.isOpen &&
        _endpoint != null &&
        !_closed) {
      return await (_reconnecting ??= _reconnect(session));
    }
    return session;
  }

  /// The new session that replaces a broken connection, while it is opened.
  Future<Session>? _reconnecting;

  /// Replaces the [broken] connection with a new one of the endpoint, and
  /// closes it.
  Future<Session> _reconnect(Connection broken) async {
    // Forced, as queries queued on the dead connection would never let it
    // close, and not awaited; its failure is logged rather than left
    // unhandled.
    unawaited(
      broken
          .close(force: true)
          .catchError(
            (Object e, StackTrace st) => logError(
              logger,
              Level.FINE,
              'Closing the broken connection failed',
              e,
              st,
            ),
          ),
    );
    logger.warning(
      "A broken database connection is detected. Creating a new database connection.",
    );
    try {
      var connection = await Connection.open(_endpoint!, settings: _settings);
      if (_closed) {
        // close() came while it was opening.
        await connection.close();
        throw StateError('The executor is closed.');
      }
      return _session = connection;
    } finally {
      _reconnecting = null;
    }
  }

  /// Runs [f] in a transaction, which is committed if it completes and
  /// rolled back if it throws. Its error is thrown as it is.
  ///
  /// On the executor of a transaction, such as the one [f] is given, [f]
  /// runs in a savepoint of that transaction, as PostgreSQL does not nest
  /// transactions: what [f] does is rolled back if it throws, even when the
  /// outer callback catches its error, and is committed with the outer
  /// transaction otherwise. Calling this on the executor of the connection
  /// from inside [f] throws, as the connection is in use by [f].
  ///
  /// Savepoints at one level of nesting run one at a time, whichever
  /// executor of the transaction they are made with. A savepoint that waits
  /// for another one at its level that it did not start inside itself, such
  /// as one started before it, waits forever, as that one waits for it.
  ///
  /// A transaction or savepoint waits for the savepoints started inside it,
  /// even ones its callback does not await, before it is committed,
  /// released or rolled back, as that would end them too. A call made after
  /// its savepoint ended, such as from a timer, runs in the one around it.
  ///
  /// A savepoint applies to the whole transaction, so a query on the
  /// executor of the transaction that runs while a savepoint of it is open,
  /// rather than on the executor its callback is given, is part of that
  /// savepoint, and rolled back with it.
  ///
  /// When the callback of a savepoint catches an error of the database
  /// itself, the transaction is aborted: the savepoint is rolled back to,
  /// and the error thrown is that of the transaction being aborted, as the
  /// callback kept the one that aborted it.
  ///
  /// A session that runs no transactions, such as one of `Connection.run`,
  /// throws a [StateError].
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    var session = await _openSession();
    if (session is TxSession) return await _savepoint(session, f);
    // A pattern, as a Session and a SessionExecutor are not related types.
    if (session case SessionExecutor executor) {
      // runTx rolls the transaction back if f throws, then throws its error.
      return await executor.runTx((tx) async {
        try {
          var level = _SavepointLevel(tx, 0, null);
          try {
            return await runZoned(
              () async => await f(PostgreSqlExecutor(tx, logger: logger)),
              zoneValues: {_savepointLevel: level},
            );
          } finally {
            await level.close();
          }
        } catch (e, st) {
          // Fine, as the error is thrown to the caller, who handles it.
          logError(
            logger,
            Level.FINE,
            'The transaction failed, and is rolled back',
            e,
            st,
          );
          rethrow;
        }
      });
    }
    throw StateError('${session.runtimeType} cannot run a transaction.');
  }

  /// Runs [f] in a savepoint of [tx], released if [f] completes and rolled
  /// back to if it throws: one level deeper than the savepoint of [tx] the
  /// call is made in, if any, after any other savepoint at that level.
  Future<T> _savepoint<T>(TxSession tx, FutureOr<T> Function(QueryExecutor) f) {
    var around = Zone.current[_savepointLevel] as _SavepointLevel?;
    if (around != null && !identical(around.tx, tx)) around = null;
    // A call made after its savepoint ended runs in the one around it.
    while (around != null && !around.isOpen) {
      around = around.parent;
    }
    var depth = (around?.depth ?? 0) + 1;

    var last = _lastSavepointsOf[tx] ??= {};
    var previous = last[depth] ?? Future<void>.value();
    var done = Completer<void>();
    last[depth] = done.future;
    // Completes without an error, so that the error stays with the caller.
    around?.started.add(done.future);
    return previous
        .then((_) => _runSavepoint(tx, depth, around, f))
        .whenComplete(done.complete);
  }

  Future<T> _runSavepoint<T>(
    TxSession tx,
    int depth,
    _SavepointLevel? around,
    FutureOr<T> Function(QueryExecutor) f,
  ) async {
    // Unique in the transaction, so that releasing or rolling back to it
    // never ends another savepoint of the same name.
    var count = (_savepointCountOf[tx] ?? 0) + 1;
    _savepointCountOf[tx] = count;
    var name = 'angel3_savepoint_$count';
    var level = _SavepointLevel(tx, depth, around);
    await tx.execute('SAVEPOINT $name');
    T result;
    try {
      try {
        result = await runZoned(
          () async => await f(PostgreSqlExecutor(tx, logger: logger)),
          zoneValues: {_savepointLevel: level},
        );
      } finally {
        await level.close();
      }
      // Fails if f left the transaction aborted, by catching an error of
      // the database itself: then it is rolled back to, as if f threw. The
      // error is then that of the transaction being aborted, as f kept the
      // one that aborted it.
      await tx.execute('RELEASE SAVEPOINT $name');
    } catch (e, st) {
      try {
        await tx.execute('ROLLBACK TO SAVEPOINT $name');
      } catch (rollbackError, rollbackStack) {
        // What f did is not undone, so the transaction cannot go on as if
        // it were: the error of the rollback is thrown instead of that of f.
        logError(logger, Level.WARNING, 'The savepoint $name failed', e, st);
        logError(
          logger,
          Level.WARNING,
          'The savepoint $name could not be rolled back',
          rollbackError,
          rollbackStack,
        );
        rethrow;
      }
      logError(
        logger,
        Level.FINE,
        'The savepoint $name failed, and is rolled back',
        e,
        st,
      );
      rethrow;
    }
    return result;
  }
}

/// The savepoint a zone runs in: its transaction, its level of nesting, 0
/// for the transaction itself, and the one it is in.
class _SavepointLevel {
  final TxSession tx;
  final int depth;
  final _SavepointLevel? parent;

  /// The ends of the savepoints started inside this one.
  final List<Future<void>> started = [];

  bool isOpen = true;

  _SavepointLevel(this.tx, this.depth, this.parent);

  /// Waits for the savepoints started inside this one, including those they
  /// start while it waits, then marks it as ended.
  Future<void> close() async {
    while (started.isNotEmpty) {
      var waiting = List.of(started);
      started.clear();
      await Future.wait(waiting);
    }
    isOpen = false;
  }
}
