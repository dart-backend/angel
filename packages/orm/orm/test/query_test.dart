import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

import '../example/main.dart';

/// A WHERE clause with a JSON column.
class _JsonWhere extends QueryWhere {
  _JsonWhere(Query query) : data = MapSqlExpressionBuilder(query, 'data');

  final MapSqlExpressionBuilder data;

  @override
  List<SqlExpressionBuilder> get expressionBuilders => [data];
}

/// Records the queries it is given; answers a `SELECT id` with [ids].
class _RecordingExecutor extends QueryExecutor {
  _RecordingExecutor(this.dialect, {this.ids = const []});

  @override
  final Dialect dialect;
  final List<int> ids;
  final queries = <String>[];

  @override
  Future<List<List>> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) async {
    queries.add(query);
    return query.startsWith('SELECT id ')
        ? [
            for (var id in ids) [id],
          ]
        : [];
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async =>
      f(this);
}

class _Text {
  final String text;
  _Text(this.text);
  @override
  String toString() => text;
}

/// Checks the SQL and substitution values queries compile to; no database is
/// needed.
void main() {
  late EmployeeQuery query;

  setUp(() => query = EmployeeQuery());

  group('like', () {
    test('passes the pattern as a parameter, not in the SQL', () {
      const injection = "x' OR '1'='1";
      query.where!.firstName.like(injection);
      var sql = query.compile({});
      expect(sql, contains('first_name LIKE @first_name'));
      expect(sql, isNot(contains("'1'='1")));
      expect(query.substitutionValues['first_name'], injection);
    });

    test('applies sanitize to the pattern', () {
      query.where!.firstName.like('Ma', sanitize: (s) => '%$s%');
      expect(query.compile({}), contains('first_name LIKE @first_name'));
      expect(query.substitutionValues['first_name'], '%Ma%');
    });
  });

  group('reserveName', () {
    test('never returns the same name twice', () {
      var names = [for (var i = 0; i < 4; i++) query.reserveName('name')];
      expect(names, ['name', 'name1', 'name2', 'name3']);
    });

    test('skips a numbered name that is already reserved', () {
      expect(query.reserveName('name1'), 'name1');
      expect(query.reserveName('name'), 'name');
      expect(query.reserveName('name'), 'name2');
    });

    test('values compiled again reuse their parameter', () {
      // E.g. one query inserted twice, with a new value the second time.
      query.values.firstName = 'a';
      query.values.compileInsert(query, 'employees');
      query.values.firstName = 'b';
      var sql = query.values.compileInsert(query, 'employees');
      expect(sql, contains('@first_name'));
      expect(
        query.substitutionValues.keys.where((k) => k.startsWith('first')),
        ['first_name'],
      );
      expect(query.substitutionValues['first_name'], 'b');
    });

    test('two values for the same column get separate parameters', () {
      // E.g. an update: `WHERE first_name = 'a'` and `SET first_name = 'b'`.
      query.where!.firstName.equals('a');
      query.values.firstName = 'b';
      var where = query.compile({});
      var set = query.values.compileForUpdate(query);

      var whereName = RegExp(r'first_name = @(\w+)').firstMatch(where)![1];
      var setName = RegExp(r'first_name=@(\w+)').firstMatch(set)![1];
      expect(whereName, isNot(setName));
      expect(query.substitutionValues[whereName], 'a');
      expect(query.substitutionValues[setName], 'b');
    });
  });

  group('mapToDouble and mapToInt', () {
    test('convert numbers of the other type', () {
      expect(mapToDouble(5), 5.0);
      expect(mapToDouble(BigInt.from(7)), 7.0);
      expect(mapToInt(5.0), 5);
      expect(mapToInt(BigInt.from(7)), 7);
    });

    test('convert values whose toString is a number', () {
      expect(mapToDouble(_Text('2.5')), 2.5);
      expect(mapToInt(_Text('42')), 42);
    });

    test('keep giving 0 for null and for strings that are not numbers', () {
      expect(mapToDouble(null), 0.0);
      expect(mapToDouble('x'), 0.0);
      expect(mapToInt(null), 0);
      expect(mapToInt('x'), 0);
    });

    test('throw instead of silently giving 0', () {
      expect(() => mapToInt(2.5), throwsFormatException);
      expect(() => mapToDouble(_Text('x')), throwsFormatException);
      expect(() => mapToInt(Object()), throwsFormatException);
    });
  });

  group('a double', () {
    test('is a plain numeric literal', () {
      query.where!.salary.lessThan(3.5);
      expect(query.where!.compile(), 'salary < 3.5');
    });

    test('that is not finite is rejected', () {
      expect(
        () => query.where!.salary.lessThan(double.nan),
        throwsArgumentError,
      );
    });
  });

  test('DateTime isIn and isNotIn bind the dates', () {
    var a = DateTime(2020, 1, 2), b = DateTime(2021, 3, 4);
    query.where!.createdAt.isIn([a, b]);
    query.where!.updatedAt.isNotIn([a]);
    var sql = query.compile({});
    expect(sql, contains('created_at IN (@created_at, @created_at1)'));
    expect(sql, contains('updated_at NOT IN (@updated_at)'));
    expect(query.substitutionValues, {
      'created_at': a,
      'created_at1': b,
      'updated_at': a,
    });
  });

  test('DateTime isIn and isNotIn of no dates are FALSE and TRUE', () {
    query.where!.createdAt.isIn([]);
    query.where!.updatedAt.isNotIn([]);
    var sql = query.compile({});
    expect(sql, contains('FALSE'));
    expect(sql, contains('TRUE'));
    expect(sql, isNot(contains('IN ()')));
  });

  test('a DateTime comparison binds the DateTime, which is sent as the '
      'executor stores a DateTime', () {
    var dt = DateTime(2020, 1, 2, 3, 4, 5);
    query.where!.createdAt.lessThan(dt);
    expect(query.compile({}), contains('created_at < @created_at'));
    expect(query.substitutionValues, {'created_at': dt});
  });

  test('a DateTime comparison without the time compares the date as given', () {
    query.where!.updatedAt.equals(
      DateTime(2020, 1, 2, 23, 59),
      includeTime: false,
    );
    expect(query.compile({}), contains("updated_at = '2020-01-02'"));
    expect(query.substitutionValues, isEmpty);
  });

  test('DateTime values are named apart from those of other columns', () {
    // A name that a DateTime predicate would make from `created_at`.
    query.reserveName('created_at1');
    query.substitutionValues['created_at1'] = 'other';
    query.where!.createdAt.isBetween(DateTime(2020), DateTime(2021));
    query.where!.createdAt.isNull;
    expect(query.substitutionValues, {'created_at1': 'other'});
  });

  test('a new DateTime predicate drops the values of the previous one', () {
    query.where!.createdAt.isBetween(DateTime(2020), DateTime(2021));
    query.where!.createdAt.isNull;
    expect(query.compile({}), contains('created_at IS NULL'));
    expect(query.substitutionValues, isEmpty);
  });

  test('a union keeps the values of both queries apart', () {
    var a = DateTime(2020), b = DateTime(2021);
    var left = EmployeeQuery()..where!.createdAt.lessThan(a);
    var right = EmployeeQuery()
      ..where!.createdAt.greaterThan(b)
      ..where!.updatedAt.equals(a);
    // A name the right query uses, which renaming must not take.
    right.substitutionValues['created_at_1'] = 'other';

    var union = left.union(right);
    var sql = union.compile({});
    expect(sql, contains('created_at < @created_at)'));
    expect(sql, contains('created_at > @created_at_2'));
    expect(union.substitutionValues, {
      'created_at': a,
      'created_at_2': b,
      'updated_at': a,
      'created_at_1': 'other',
    });
  });

  group('JSON', () {
    late _JsonWhere where;

    setUp(() => where = _JsonWhere(query));

    test('property null checks are joined with AND', () {
      where.data['a'].isNotNull;
      where.data['b'].isNull;
      expect(
        where.compile(),
        "data::jsonb->>'a' IS NOT NULL AND data::jsonb->>'b' IS NULL",
      );
    });

    test('typed properties are joined with AND', () {
      where.data['a'].asString!.equals('x');
      where.data['b'].isNotNull;
      expect(
        where.compile(),
        matches(
          r"^data::jsonb->>'a' = @prop\w* AND data::jsonb->>'b' IS NOT NULL$",
        ),
      );
    });

    test('the column itself can be checked', () {
      where.data.isNull;
      expect(where.compile(), 'data IS NULL');
    });

    test('every predicate gets the table name', () {
      where.data['a'].isNotNull;
      where.data['b'].isNull;
      expect(
        where.compile(tableName: 't'),
        "t.data::jsonb->>'a' IS NOT NULL AND t.data::jsonb->>'b' IS NULL",
      );
    });
  });

  group('nested clauses', () {
    test('notWhere is joined with AND', () {
      query.where!.id.equals(1);
      query.notWhere((w) => w.firstName.equals('x'));
      expect(
        query.compile({}),
        contains('WHERE id = 1 AND NOT (first_name = @first_name)'),
      );
    });

    test('a query with only orWhere has no leading OR', () {
      query.orWhere((w) => w.firstName.equals('x'));
      var sql = query.compile({});
      expect(sql, contains('WHERE (first_name = @first_name)'));
      expect(sql, isNot(contains('WHERE  OR')));
    });

    test('a query with only andWhere has no leading AND', () {
      query.andWhere((w) => w.firstName.equals('x'));
      expect(query.compile({}), contains('WHERE (first_name = @first_name)'));
    });

    test('orWhere follows the other conditions', () {
      query.where!.id.equals(1);
      query.orWhere((w) => w.firstName.equals('x'));
      expect(
        query.compile({}),
        contains('WHERE id = 1 OR (first_name = @first_name)'),
      );
    });
  });

  group('DateTime parts', () {
    test('use EXTRACT, which PostgreSQL and MySQL both support', () {
      query.where!.createdAt
        ..year.equals(2020)
        ..month.equals(3)
        ..second.equals(5);
      expect(
        query.where!.compile(),
        'EXTRACT(YEAR FROM created_at) = 2020 AND '
        'EXTRACT(MONTH FROM created_at) = 3 AND '
        'FLOOR(EXTRACT(SECOND FROM created_at)) = 5',
      );
    });

    test('every part, and a direct predicate, gets the table name', () {
      query.where!.createdAt
        ..year.equals(2020)
        ..day.equals(1);
      query.where!.updatedAt.isNull;
      expect(
        query.where!.compile(tableName: 'e'),
        'EXTRACT(YEAR FROM e.created_at) = 2020 AND '
        'EXTRACT(DAY FROM e.created_at) = 1 AND e.updated_at IS NULL',
      );
    });
  });

  group('update', () {
    setUp(() {
      query.where!.lastName.equals('old');
      query.values.lastName = 'new';
    });

    group('on PostgreSQL', () {
      late _RecordingExecutor executor;

      setUp(() => executor = _RecordingExecutor(const PostgreSQLDialect()));

      test('returns the updated rows without filtering them again', () async {
        await query.update(executor);
        var sql = executor.queries.single;
        expect(
          sql,
          startsWith(
            'WITH employees as (UPDATE employees SET last_name=@last_name1 '
            'WHERE last_name = @last_name RETURNING ',
          ),
        );
        var select = sql.substring(sql.indexOf(') SELECT ') + 2);
        expect(select, isNot(contains('WHERE')));
      });

      test('picks the rows of a limit by ctid', () async {
        query.limit(2);
        await query.update(executor);
        var sql = executor.queries.single;
        expect(
          sql,
          contains(
            'WHERE ctid IN (SELECT ctid FROM employees '
            'WHERE last_name = @last_name LIMIT 2) RETURNING ',
          ),
        );
        var select = sql.substring(sql.indexOf(') SELECT ') + 2);
        expect(select, isNot(contains('LIMIT')));
      });
    });

    group('on MySQL', () {
      test('updates and returns exactly the matching rows, by id', () async {
        var executor = _RecordingExecutor(const MySQLDialect(), ids: [3, 7]);
        query.limit(2);
        await query.update(executor);
        expect(executor.queries, hasLength(3));
        expect(
          executor.queries[0],
          'SELECT id FROM employees WHERE last_name = @last_name LIMIT 2',
        );
        expect(
          executor.queries[1],
          'UPDATE employees SET last_name=@last_name1 WHERE id IN (3, 7)',
        );
        expect(executor.queries[2], endsWith(' WHERE employees.id IN (3, 7)'));
        expect(executor.queries[2], isNot(contains('last_name = @')));
      });

      test('updates nothing when no row matches', () async {
        var executor = _RecordingExecutor(const MySQLDialect());
        expect(await query.update(executor), isEmpty);
        expect(executor.queries, hasLength(1));
      });
    });
  });

  group('getOne', () {
    late _RecordingExecutor executor;

    setUp(() => executor = _RecordingExecutor(const PostgreSQLDialect()));

    test('fetches one row, and leaves the query as it was', () async {
      await query.getOne(executor);
      expect(executor.queries.single, endsWith(' LIMIT 1'));
      expect(query.compile({}), isNot(contains('LIMIT')));
    });

    test("keeps the query's own limit", () async {
      query.limit(5);
      await query.getOne(executor);
      expect(executor.queries.single, endsWith(' LIMIT 5'));
    });
  });
}
