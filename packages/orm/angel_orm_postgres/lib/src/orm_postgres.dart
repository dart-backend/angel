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

  /// An optional [Logger] to print information to. A default logger will be used
  /// if not set
  late Logger logger;

  @override
  Dialect get dialect => _dialect;

  /// The underlying database session.
  Session get session => _session;

  PostgreSqlExecutor(this._session,
      {Endpoint? endpoint, ConnectionSettings? settings, Logger? logger}) {
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
      String tableName, String query, Map<String, dynamic> substitutionValues,
      {String returningQuery = '', List<String> returningFields = const []}) {
    if (returningFields.isNotEmpty) {
      var fields = returningFields.join(', ');
      var returning = 'RETURNING $fields';
      query = '$query $returning';
    }

    logger.fine('Query: $query');
    logger.fine('Values: $substitutionValues');

    // Convert List into String
    var param = <String, dynamic>{};
    substitutionValues.forEach((key, value) {
      if (value is List) {
        param[key] = jsonEncode(value);
      } else {
        param[key] = value;
      }
    });

    return _session
        .execute(Sql.named(query), parameters: param)
        .catchError((err) async {
      logger.warning(err);
      if (err is PgException) {
        // This is a hack to detect broken db connection
        bool brokenConnection = err.message.contains("connection is not open");
        if (brokenConnection) {
          // Open a new db session
          if (_session is Connection) {
            (_session as Connection).close();

            logger.warning(
                "A broken database connection is detected. Creating a new database connection.");
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

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    //if (_connection is! PostgreSQLConnection) {
    //  return await f(this);
    //}

    var conn = _session as Connection;

    return await conn.runTx((TxSession session) async {
      try {
        var exec = PostgreSqlExecutor(session, logger: logger);
        return await f(exec);
      } catch (e) {
        session.rollback();
        logger.warning("The transation has failed due to ", e);
        rethrow;
      }
    }).onError((error, stackTrace) {
      throw StateError('The transaction was cancelled.');
    });
  }
}
