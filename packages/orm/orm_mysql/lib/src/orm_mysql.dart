import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:mysql_dart/mysql_protocol.dart' show MySQLColumnType;

part 'orm_mariadb.dart';

/// The commands of a connection that have not completed, which
/// [MySqlExecutor.close] waits for, as `mysql_dart` closes a connection only
/// when none runs; and the key of its transactions in a zone.
///
/// `mysql_dart` runs the commands of a connection one at a time, in the
/// order they are given, and those of a transaction's callback in it.
class _Connection {
  final Set<Future<void>> running = {};
  final Object transactionKey = Object();
}

/// A transaction on a connection, which `mysql_dart` holds the connection
/// for: the commands given in [zone], that of its callback, run in it.
class _Transaction {
  late final Zone zone;

  /// The commands given in it that have not completed.
  final Set<Future<void>> running = {};

  /// Whether it has ended, after which it runs no command, as one would run
  /// outside it.
  bool ended = false;

  /// Waits for the commands given in it, and for those they lead to, as the
  /// later steps of an operation of the ORM that was not awaited: each step
  /// is given once the one before completes, in microtasks, which all run
  /// before a timer.
  Future<void> drain() async {
    do {
      await Future.wait(List.of(running));
      await Future<void>.delayed(Duration.zero);
    } while (running.isNotEmpty);
  }
}

class MySqlExecutor extends QueryExecutor {
  /// The [Logger] written to.
  Logger logger;

  final MySQLConnection _connection;

  /// The state of [_connection], which all its executors share.
  final _Connection _state;

  /// The transaction of this executor, if it is of one, of [transaction].
  final _Transaction? _transaction;

  /// Whether a [DateTime] is stored as UTC, as of [MariaDbExecutor], rather
  /// than as local time.
  final bool _utc;

  /// The state of each connection.
  static final Expando<_Connection> _connections = Expando(
    'MySqlExecutor connection',
  );

  MySqlExecutor(MySQLConnection connection, {Logger? logger})
    : this._(connection, logger ?? Logger('MySqlExecutor'), utc: false);

  MySqlExecutor._(
    this._connection,
    this.logger, {
    required this._utc,
    this._transaction,
  }) : _state = _connections[_connection] ??= _Connection();

  /// The executor of [transaction], of the type of this one, which stores a
  /// [DateTime] as this one does.
  MySqlExecutor _of(_Transaction transaction) =>
      MySqlExecutor._(_connection, logger, utc: _utc, transaction: transaction);

  final Dialect _dialect = const MySQLDialect();

  @override
  Dialect get dialect => _dialect;

  /// Closes the connection once the commands given before have run.
  ///
  /// Throws a [StateError] of the executor of a transaction, whose
  /// connection is that of the transaction, which ends it, and in a
  /// transaction on the connection, which the close would wait for, as the
  /// transaction for it.
  Future<void> close() async {
    if (_transaction != null || _zoneTransaction != null) {
      throw StateError('The connection of a transaction is not closed in it.');
    }
    while (_state.running.isNotEmpty) {
      await Future.wait(List.of(_state.running));
    }
    await _connection.close();
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
  }) {
    if (_transaction?.ended == true) {
      return Future.error(
        StateError('The transaction of this executor has ended.'),
      );
    }
    return _query(query, substitutionValues, returningQuery: returningQuery);
  }

  /// Whether a query is an insert, of which [_query] selects the row.
  static final RegExp _insert = RegExp(r'^\s*INSERT\b', caseSensitive: false);

  /// The rows of [query], or, of an insert with [returningQuery], those of
  /// the select of its row.
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
      var result = await _execute(sql, params);
      params = [];
      sql = _toPositional(returningQuery, {
        ...substitutionValues,
        // As it is, as an id of a BIGINT UNSIGNED may exceed an int.
        insertIdParameter: result.lastInsertID,
      }, params);
    }

    return parseSQLResult(await _execute(sql, params));
  }

  /// Executes [sql] with [params]: in the transaction of this executor, or
  /// in the one on the connection that runs in the current zone, as a query
  /// given by its code to another executor of the connection would wait for
  /// it, and it for the query.
  Future<IResultSet> _execute(String sql, List<dynamic> params) {
    var transaction = _transaction ?? _zoneTransaction;
    var result = transaction == null
        ? _connection.execute(sql, params)
        // In its zone, by which `mysql_dart` runs it in the transaction, as
        // a callback of a stream or a timer may run in another.
        : transaction.zone.run(() => _connection.execute(sql, params));
    var done = result.then<void>((_) {}, onError: (_) {});
    _state.running.add(done);
    transaction?.running.add(done);
    done.whenComplete(() {
      _state.running.remove(done);
      transaction?.running.remove(done);
    });
    return result;
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

  /// The values of the rows of [res], as `mysql_dart` gives them, with each
  /// date or time as a [DateTime]: as UTC if [_utc], or else as local time.
  ///
  /// A date that [DateTime] cannot represent, as the zero date
  /// (`0000-00-00`), which MySQL stores where the SQL mode allows it, or
  /// `2024-02-30`, under `ALLOW_INVALID_DATES`, is `null`, rather than
  /// another day.
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

  /// A date or time as the server sends it: `2024-03-10`,
  /// `2024-03-10 12:34:56` or `2024-03-10 12:34:56.123456`.
  static final RegExp _dateTimeText = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?)?$',
  );

  /// The value of [text] of a date or time column. Its fields are read as
  /// they are, so that a UTC one is never read as local time, which has no
  /// time in the gap of a change to daylight saving time.
  Object? _dateTime(String text) {
    var match = _dateTimeText.firstMatch(text);
    if (match == null) return text;
    int field(int i) => int.parse(match[i] ?? '0');
    var (year, month, day) = (field(1), field(2), field(3));
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day) {
      return null;
    }
    // '.5' is half a second.
    var microsecond = int.parse((match[7] ?? '').padRight(6, '0'));
    var fields = (field(4), field(5), field(6));
    return _utc
        ? DateTime.utc(
            year,
            month,
            day,
            fields.$1,
            fields.$2,
            fields.$3,
            0,
            microsecond,
          )
        : DateTime(
            year,
            month,
            day,
            fields.$1,
            fields.$2,
            fields.$3,
            0,
            microsecond,
          );
  }

  /// The transaction on [_connection] that runs in the current zone, if it
  /// has not ended.
  _Transaction? get _zoneTransaction {
    var transaction = Zone.current[_state.transactionKey];
    return transaction is _Transaction && !transaction.ended
        ? transaction
        : null;
  }

  /// Runs [f] in a transaction, which holds the connection: the queries of
  /// [f], including those not awaited, and those they lead to, run in it,
  /// before its `COMMIT` or `ROLLBACK`.
  ///
  /// A transaction in a transaction on the connection, as of the executor of
  /// a transaction, is of that one, as MySQL nests none; [f] is given an
  /// executor of it that stores a [DateTime] as this one does.
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    if (_transaction != null) return f(this);
    var current = _zoneTransaction;
    if (current != null) return f(_of(current));

    return _connection.transactional((_) async {
      var transaction = _Transaction();
      try {
        return await runZoned(() {
          transaction.zone = Zone.current;
          return Future.sync(() => f(_of(transaction)));
        }, zoneValues: {_state.transactionKey: transaction});
      } catch (e, st) {
        // Fine, as the error is thrown to the caller, who handles it.
        logger.fine('The transaction failed, and is rolled back', e, st);
        rethrow;
      } finally {
        await transaction.drain();
        transaction.ended = true;
      }
    });
  }
}
