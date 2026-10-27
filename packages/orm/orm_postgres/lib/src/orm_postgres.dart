import 'dart:async';
import 'dart:convert';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

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

  /// Closes the connection.
  Future<void> close() async {
    if (_session is Connection) {
      await (_session as Connection).close();
    }

    return Future.value();
  }

  @override
  Future<Result> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) {
    //if (returningFields.isNotEmpty) {
    //  var fields = returningFields.join(', ');
    //  var returning = 'SELECT $fields from $tableName';
    //  query = '$query $returning';
    //}

    logger.fine('Query: $query');
    logger.fine('Values: $substitutionValues');
    logger.fine('Returning Query: $returningQuery');

    // Convert List into String
    var param = <String, dynamic>{};
    substitutionValues.forEach((key, value) {
      if (value is List) {
        param[key] = jsonEncode(value);
      } else {
        param[key] = value;
      }
    });

    return _session.execute(Sql.named(query), parameters: param).catchError((
      err,
    ) async {
      logger.warning(err);
      if (err is PgException) {
        // This is a hack to detect broken db connection
        bool brokenConnection = err.message.contains("connection is not open");
        if (brokenConnection) {
          // Open a new db session
          if (_session is Connection) {
            (_session as Connection).close();

            logger.warning(
              "A broken database connection is detected. Creating a new database connection.",
            );
            _session = await _createNewSession();

            // Retry the query with the new db connection
            return _session.execute(Sql.named(query), parameters: param);
          }
        }
      }
      throw err;
    });
  }

  // Create a new database connection
  Future<Session> _createNewSession() async {
    if (_endpoint != null) {
      return await Connection.open(_endpoint!, settings: _settings);
    }

    throw PgException("Unable to create new connection");
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
    var session = _session;
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
          logger.fine('The transaction failed, and is rolled back', e, st);
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
        logger.warning('The savepoint $name failed', e, st);
        logger.warning(
          'The savepoint $name could not be rolled back',
          rollbackError,
          rollbackStack,
        );
        rethrow;
      }
      logger.fine('The savepoint $name failed, and is rolled back', e, st);
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
