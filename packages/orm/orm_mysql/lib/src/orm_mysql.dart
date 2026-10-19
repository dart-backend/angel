import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:mysql_dart/mysql_protocol.dart' show MySQLColumnType;

part 'orm_mariadb.dart';

/// The commands of a connection, which run one at a time, in the order they
/// are given, as `mysql_dart` runs one command at a time on a connection: it
/// rejects, or fails to decode the response of, one sent while another runs.
class _CommandQueue {
  Future<void> _tail = Future<void>.value();

  /// Runs [command] once those given before it have run.
  Future<T> run<T>(Future<T> Function() command) {
    var result = _tail.then((_) => command());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}

class MySqlExecutor extends QueryExecutor {
  /// The [Logger] written to.
  Logger logger;

  final MySQLConnection _connection;

  /// The queue of the commands of [_connection]: that of the connection, which
  /// all its executors share, or, of the executor of a transaction, its own,
  /// as the transaction holds the connection's turn while it runs.
  final _CommandQueue _queue;

  /// Whether this is the executor of a transaction, of [transaction].
  final bool _inTransaction;

  /// Whether the transaction of this executor has ended, after which it runs
  /// no query, as it would run out of the connection's turn.
  bool _ended = false;

  /// Whether a [DateTime] is stored as UTC, as of [MariaDbExecutor], rather
  /// than as local time.
  final bool _utc;

  /// The queue of each connection.
  static final Expando<_CommandQueue> _queues = Expando('MySqlExecutor queue');

  /// The key, with the connection, of the executor of the transaction that
  /// runs on it in a zone, of [transaction].
  static final Object _transactionKey = Object();

  MySqlExecutor(MySQLConnection connection, {Logger? logger})
    : this._(connection, logger ?? Logger('MySqlExecutor'), utc: false);

  MySqlExecutor._(this._connection, this.logger, {required this._utc})
    : _queue = _queues[_connection] ??= _CommandQueue(),
      _inTransaction = false;

  /// The executor of a transaction on [_connection], whose turn it holds.
  MySqlExecutor._transaction(this._connection, this.logger, this._utc)
    : _queue = _CommandQueue(),
      _inTransaction = true;

  /// The executor of a transaction on [connection], of the type of this one.
  MySqlExecutor _newTransaction(MySQLConnection connection) =>
      MySqlExecutor._transaction(connection, logger, _utc);

  final Dialect _dialect = const MySQLDialect();

  @override
  Dialect get dialect => _dialect;

  /// Closes the connection once the commands given before have run.
  ///
  /// Throws a [StateError] of the executor of a transaction, whose
  /// connection is that of the transaction, which ends it.
  Future<void> close() {
    if (_inTransaction) {
      return Future.error(
        StateError('The executor of a transaction does not close it.'),
      );
    }
    return _queue.run(() => _connection.close());
  }

  MySQLConnection get rawConnection => _connection;

  @override
  Future<List<List>> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) => _run(
    () => _query(query, substitutionValues, returningQuery: returningQuery),
  );

  /// Whether a query is an insert, of which [_query] selects the row.
  static final RegExp _insert = RegExp(r'^\s*INSERT\b', caseSensitive: false);

  /// The rows of [query], whose commands, as an insert and the select of its
  /// row, run in one turn of the queue of the connection.
  Future<List<List>> _query(
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
  }) async {
    var params = <dynamic>[];
    var sql = _toPositional(query, substitutionValues, params);

    // The row inserted, by its id: the one given, of its parameter, or that
    // the database gave it, of [insertIdParameter].
    if (returningQuery.isNotEmpty && _insert.hasMatch(sql)) {
      var result = await _connection.execute(sql, params);
      params = [];
      sql = _toPositional(returningQuery, {
        ...substitutionValues,
        // As an int, as `mysql_dart` binds no BigInt.
        insertIdParameter: result.lastInsertID.toInt(),
      }, params);
    }

    return parseSQLResult(await _connection.execute(sql, params));
  }

  /// Changes the `@name` placeholders in [sql] to `?`, and adds their values
  /// to [params] in the order the placeholders appear, which `mysql_dart`
  /// binds as those of a prepared statement. A [DateTime] is sent as local
  /// time, or as UTC if [_utc].
  String _toPositional(
    String sql,
    Map<String, dynamic> substitutionValues,
    List<dynamic> params,
  ) {
    return replacePlaceholders(sql, substitutionValues, (_, value) {
      if (value is DateTime) {
        value = _utc ? value.toUtc() : value.toLocal();
      }
      params.add(value);
      return '?';
    });
  }

  /// The types of the columns of a date or time.
  static final Set<int> _dateTimeTypes = {
    MySQLColumnType.dateType.intVal,
    MySQLColumnType.dateTimeType.intVal,
    MySQLColumnType.dateTime2Type.intVal,
    MySQLColumnType.timestampType.intVal,
    MySQLColumnType.timestamp2Type.intVal,
  };

  /// The values of the rows of [res], as `mysql_dart` gives them: as text.
  ///
  /// A zero date or time (`0000-00-00`), which is no [DateTime], is `null`,
  /// and, if [_utc], a date or time is a UTC [DateTime], as the text would
  /// be parsed as local time.
  List<List<dynamic>> parseSQLResult(IResultSet res) {
    var dateTimeColumns = <int>{
      for (var (i, col) in res.cols.indexed)
        if (_dateTimeTypes.contains(col.type.intVal)) i,
    };

    var mappedResult = <List>[];
    for (var row in res.rows) {
      List<dynamic> retResult = [];
      for (var i = 0; i < row.numOfColumns; i++) {
        var val = row.typedColAt(i);
        if (dateTimeColumns.contains(i) && val is String) {
          val = _dateTime(val);
        }
        retResult.add(val);
      }
      mappedResult.add(retResult);
    }

    return mappedResult;
  }

  /// The value of [text] of a date or time column.
  Object? _dateTime(String text) {
    if (text.startsWith('0000-00-00')) return null;
    if (!_utc) return text;
    var local = DateTime.tryParse(text);
    if (local == null) return text;
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  /// The executor of the transaction that runs on [_connection] in the
  /// current zone, if it has not ended.
  MySqlExecutor? get _zoneTransaction {
    var tx = Zone.current[(_transactionKey, _connection)];
    return tx is MySqlExecutor && !tx._ended ? tx : null;
  }

  /// Runs [command] in the queue of this executor, or throws a [StateError]
  /// if it is of a transaction that has ended.
  ///
  /// A command given in a transaction on the connection, as by its code to
  /// an executor of the connection other than that of the transaction, runs
  /// in the transaction, as it would wait for the transaction, which holds
  /// the turn of the connection, and the transaction for it.
  Future<T> _run<T>(Future<T> Function() command) {
    if (_ended) {
      return Future.error(
        StateError('The transaction of this executor has ended.'),
      );
    }
    var tx = _inTransaction ? null : _zoneTransaction;
    if (tx != null) return tx._queue.run(command);
    return _queue.run(command);
  }

  /// Runs [f] in a transaction, in one turn of the queue of the connection,
  /// whose queries run one at a time in a queue of their own. A transaction
  /// in a transaction on the connection, as of the executor of a
  /// transaction, is of that one, as MySQL nests none.
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    if (_inTransaction) return f(this);
    var current = _zoneTransaction;
    if (current != null) return f(current);

    return _run(
      () => _connection.transactional((ctx) async {
        var tx = _newTransaction(ctx);
        try {
          return await runZoned(
            () async => await f(tx),
            zoneValues: {(_transactionKey, _connection): tx},
          );
        } catch (e) {
          logger.severe('Failed to run transaction', e);
          rethrow;
        } finally {
          // Its turn is the transaction's, which ends with it.
          tx._ended = true;
        }
      }),
    );
  }
}
