import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:optional/optional.dart';
import 'package:test/test.dart';

import '../example/main.dart';

class _JsonWhere extends QueryWhere {
  _JsonWhere(Query query) : data = MapSqlExpressionBuilder(query, 'data');

  final MapSqlExpressionBuilder data;

  @override
  List<SqlExpressionBuilder> get expressionBuilders => [data];
}

/// Records the queries it is given; answers a `SELECT` with [rows].
class _Executor extends QueryExecutor {
  _Executor(this.dialect, {this.rows = const []});

  @override
  final Dialect dialect;
  final List<List> rows;
  final queries = <String>[];
  final returningQueries = <String>[];
  final values = <Map<String, dynamic>>[];

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
    returningQueries.add(returningQuery);
    values.add(substitutionValues);
    return query.startsWith('SELECT') || query.startsWith('(') ? rows : [];
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async =>
      f(this);
}

/// A table without an id.
class _NoIdQuery extends EmployeeQuery {
  @override
  List<String> get fields => const ['last_name'];

  @override
  Optional<Employee> deserialize(List row) => Optional.empty();
}

/// Loads a relation: here, it gives every record a last name.
class _RelationsQuery extends EmployeeQuery {
  @override
  bool get loadsRelations => true;

  @override
  Future<List<Employee>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<Employee> records,
    Set<String> loading,
  ) async => [for (var r in records) r.copyWith(lastName: 'loaded')];
}

const _row = [3, null, null, 'first', 'last', 1.0];

void main() {
  late EmployeeQuery query;
  late _JsonWhere json;

  setUp(() {
    query = EmployeeQuery();
    json = _JsonWhere(query);
  });

  group('isIn and isNotIn of no values', () {
    test('are FALSE and TRUE on a number', () {
      query.where!.id.isIn(const []);
      query.where!.salary.isNotIn(const []);
      expect(query.where!.compile(), 'FALSE AND TRUE');
    });

    test('are FALSE and TRUE on a string', () {
      query.where!.firstName.isIn(const []);
      query.where!.lastName.isNotIn(const []);
      expect(query.where!.compile(tableName: 'e'), 'FALSE AND TRUE');
      expect(query.substitutionValues, isEmpty);
    });

    test('are FALSE and TRUE on an enum', () {
      var e = EnumSqlExpressionBuilder<int>(query, 'kind', (v) => v);
      expect((e..isIn(const [])).compileFor('kind'), 'FALSE');
      expect((e..isNotIn(const [])).compileFor('kind'), 'TRUE');
      expect((e..isIn(const [1, 2])).compileFor('kind'), 'kind IN (1, 2)');
    });
  });

  group('a JSON property', () {
    const n =
        "CASE WHEN jsonb_typeof(data::jsonb->'n') = 'number' "
        "THEN (data::jsonb->>'n')::numeric END";

    test('as a number is compared as one', () {
      json.data['n'].asInt!.greaterThan(5);
      expect(json.compile(), '$n > 5');
    });

    test('as a number supports isBetween', () {
      json.data['n'].asInt!.isBetween(1, 5);
      expect(json.compile(), '$n BETWEEN 1 AND 5');
    });

    test('as a number supports isIn', () {
      json.data['n'].asDouble!.isIn([1.5]);
      expect(json.compile(), '$n IN (1.5)');
    });

    test('as a date binds one parameter, and gets the table name', () {
      var dt = DateTime(2020);
      json.data['at'].asDateTime!.lessThan(dt);
      expect(
        json.compile(tableName: 't'),
        "CAST (t.data::jsonb->>'at' AS timestamptz) < @prop",
      );
      expect(query.substitutionValues, {'prop': dt});
    });

    test('as a map or a list names its column once', () {
      json.data['a'].asMap!.contains({'x': 1});
      expect(json.compile(), "(data::jsonb->>'a')::jsonb @> @prop::jsonb");
    });

    test('nested, is a property of the property', () {
      json.data['a'].asMap!['b'].asString!.equals('x');
      expect(json.compile(), "(data::jsonb->>'a')::jsonb->>'b' = @prop");
    });

    test('as a string names the values of isIn apart from its name', () {
      json.data['a'].asString!.isIn(['x']);
      expect(json.compile(), "data::jsonb->>'a' IN (@prop_in_value)");
      expect(query.substitutionValues, {'prop_in_value': 'x'});
    });

    test("has a ' in its key escaped", () {
      json.data["x' OR '1'='1"].isNotNull;
      expect(json.compile(), "data::jsonb->>'x'' OR ''1''=''1' IS NOT NULL");
    });
  });

  test('a date predicate is joined with those of its parts', () {
    query.where!.createdAt
      ..isNotNull
      ..year.equals(2020);
    expect(
      query.where!.compile(),
      'created_at IS NOT NULL AND EXTRACT(YEAR FROM created_at) = 2020',
    );
  });

  test('a self join is an INNER JOIN of the table, by an alias', () {
    query.selfJoin('employees', 'id', 'id', alias: 'm');
    expect(
      query.compile({}),
      contains(' INNER JOIN employees m ON employees.id=m.id'),
    );
  });

  group('an expression', () {
    setUp(() => query.expressions['last_name'] = 'po.name');

    test('is left out of a RETURNING, for the select around it', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await query.delete(executor);
      var sql = executor.queries.single;
      expect(sql, contains('RETURNING employees.id,'));
      expect(
        sql.substring(0, sql.indexOf(') SELECT ')),
        isNot(contains('po.')),
      );
      expect(sql, contains('( po.name ) AS last_name'));
    });

    test('is valid SQL in a condition', () {
      expect(query.adornWithTableName('last_name'), '(po.name)');
    });
  });

  group('delete', () {
    setUp(() {
      query.where!.lastName.equals('old');
      query
        ..orderBy('salary', descending: true)
        ..limit(1)
        ..offset(2);
    });

    test('on PostgreSQL picks the rows by ctid, in order', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await query.delete(executor);
      var sql = executor.queries.single;
      expect(
        sql,
        startsWith(
          'WITH employees as (DELETE FROM employees WHERE ctid IN '
          '(SELECT ctid FROM employees WHERE last_name = @last_name '
          'ORDER BY salary DESC LIMIT 1 OFFSET 2) RETURNING ',
        ),
      );
      var select = sql.substring(sql.indexOf(') SELECT ') + 2);
      expect(select, isNot(contains('LIMIT')));
      expect(select, isNot(contains('OFFSET')));
      expect(select, isNot(contains('WHERE')));
    });

    test('on MySQL deletes the rows it selected, by id', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row]);
      expect(await query.delete(executor), hasLength(1));
      expect(executor.queries[0], endsWith(' LIMIT 1 OFFSET 2'));
      expect(executor.queries[1], 'DELETE FROM employees WHERE id IN (3)');
    });

    test('on MySQL deletes nothing when no row matches', () async {
      var executor = _Executor(const MySQLDialect());
      expect(await query.delete(executor), isEmpty);
      expect(executor.queries, hasLength(1));
    });

    test('without a limit has no ORDER BY', () async {
      var executor = _Executor(const MySQLDialect());
      var q = EmployeeQuery()..orderBy('salary');
      await q.delete(executor);
      expect(executor.queries[1], 'DELETE FROM employees');
    });

    test('on PostgreSQL of a join deletes the rows it selected, by id, and '
        'gives only the values it uses', () async {
      var executor = _Executor(const PostgreSQLDialect(), rows: [_row]);
      query.join('companies', 'company_id', 'id');
      expect(await query.delete(executor), hasLength(1));
      expect(executor.queries, hasLength(2));
      expect(executor.queries[0], startsWith('SELECT '));
      expect(executor.queries[1], 'DELETE FROM employees WHERE id IN (3)');
      expect(executor.values[1], isEmpty);
    });

    test('of a relation deletes the rows it selected, by id', () async {
      var executor = _Executor(const PostgreSQLDialect(), rows: [_row]);
      var q = _RelationsQuery()..limit(1);
      expect((await q.delete(executor)).single.lastName, 'loaded');
      expect(executor.queries[1], 'DELETE FROM employees WHERE id IN (3)');
    });

    test('of a join, without a limit, is by id too', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row]);
      await (EmployeeQuery()..join('companies', 'company_id', 'id')).delete(
        executor,
      );
      expect(executor.queries[1], 'DELETE FROM employees WHERE id IN (3)');
    });

    test('binds an id that is not an int, and deletes each once', () async {
      var row = ['a-uuid', ..._row.skip(1)];
      var executor = _Executor(const MySQLDialect(), rows: [row, row]);
      await (EmployeeQuery()..limit(2)).delete(executor);
      expect(
        executor.queries[1],
        'DELETE FROM employees WHERE id IN (@id_key0)',
      );
      expect(executor.values[1], {'id_key0': 'a-uuid'});
    });

    test('deletes many ids in parts', () async {
      var executor = _Executor(
        const MySQLDialect(),
        rows: [
          for (var i = 1; i <= 1500; i++) [i, ..._row.skip(1)],
        ],
      );
      await (EmployeeQuery()..limit(1500)).delete(executor);
      expect(executor.queries, hasLength(3));
    });

    group('of a query that selects no id', () {
      test('on PostgreSQL has a limit, in one statement', () async {
        var executor = _Executor(const PostgreSQLDialect());
        await (_NoIdQuery()..limit(1)).delete(executor);
        expect(executor.queries.single, startsWith('WITH '));
      });

      test('on MySQL has no limit or offset', () {
        for (var q in [_NoIdQuery()..limit(1), _NoIdQuery()..offset(1)]) {
          expect(q.delete(_Executor(const MySQLDialect())), throwsStateError);
        }
      });

      test('has no join that can leave a row out', () {
        for (var dialect in const [PostgreSQLDialect(), MySQLDialect()]) {
          var q = _NoIdQuery()..join('companies', 'company_id', 'id');
          expect(q.delete(_Executor(dialect)), throwsStateError);
        }
      });

      test('has a left join, by its conditions', () async {
        var executor = _Executor(const PostgreSQLDialect());
        var q = _NoIdQuery()..leftJoin('companies', 'company_id', 'id');
        q.where!.lastName.equals('x');
        await q.delete(executor);
        expect(
          executor.queries[1],
          'DELETE FROM employees WHERE employees.last_name = @last_name',
        );
        expect(executor.values[1], {'last_name': 'x'});
      });
    });

    test('with a GROUP BY is an error, on either database', () {
      query.groupBy('salary');
      for (var dialect in const [PostgreSQLDialect(), MySQLDialect()]) {
        expect(query.delete(_Executor(dialect)), throwsStateError);
      }
    });
  });

  group('update under a limit', () {
    setUp(() {
      query.values.lastName = 'new';
      query
        ..orderBy('salary', descending: true)
        ..limit(1);
    });

    test('on PostgreSQL picks the first rows in order', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await query.update(executor);
      expect(
        executor.queries.single,
        contains(
          'WHERE ctid IN (SELECT ctid FROM employees '
          'ORDER BY salary DESC LIMIT 1) RETURNING ',
        ),
      );
    });

    test('on MySQL picks the first rows in order', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row]);
      await query.update(executor);
      expect(
        executor.queries.first,
        'SELECT id FROM employees ORDER BY salary DESC LIMIT 1',
      );
    });

    test(
      'on MySQL without an id has no limit or offset, updating no row',
      () async {
        for (var q in [_NoIdQuery()..limit(1), _NoIdQuery()..offset(1)]) {
          q.values.lastName = 'new';
          var executor = _Executor(const MySQLDialect());
          await expectLater(q.update(executor), throwsStateError);
          expect(executor.queries, isEmpty);
        }
      },
    );
  });

  group('insert of a query with conditions', () {
    setUp(() {
      query.where!.firstName.equals('other');
      query.values.lastName = 'new';
      query.limit(1);
    });

    test('on PostgreSQL does not filter out the row', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await query.insert(executor);
      var sql = executor.queries.single;
      var select = sql.substring(sql.indexOf(') SELECT ') + 2);
      expect(select, isNot(contains('WHERE')));
      expect(select, isNot(contains('LIMIT')));
    });

    test('on MySQL selects the row by its id alone', () async {
      var executor = _Executor(const MySQLDialect());
      await query.insert(executor);
      expect(
        executor.returningQueries.single,
        endsWith(' FROM employees WHERE employees.id=@$insertIdParameter'),
      );
    });
  });

  group('compileForUpdate', () {
    test('leaves the values given as they are', () {
      var values = MapQueryValues()
        ..values.addAll({'name': 'x', 'created_at': null, 'updated_at': null});
      var sql = values.compileForUpdate(query);
      expect(sql, 'SET name=@name, updated_at=@updated_at');
      expect(values.values, {
        'name': 'x',
        'created_at': null,
        'updated_at': null,
      });
    });

    test('is empty, not a bare SET, with only a null created_at', () {
      var values = MapQueryValues()..values['created_at'] = null;
      expect(values.compileForUpdate(query), '');
    });

    test('rejects a key that is no column name', () {
      var values = MapQueryValues()..values['a=1; DROP TABLE users; --'] = 1;
      expect(() => values.compileForUpdate(query), throwsArgumentError);
    });

    test('keeps a column the query does not select', () {
      query.values.lastName = 'new';
      var narrowed = _NoIdQuery();
      var values = MapQueryValues()..values['first_name'] = 'x';
      expect(values.compileForUpdate(narrowed), 'SET first_name=@first_name');
    });
  });

  group('a union', () {
    test('renames the values of the right query, not text in quotes', () {
      var left = EmployeeQuery()..where!.firstName.equals('a');
      var right = EmployeeQuery()..where!.firstName.equals('b');
      right.where!.raw("note = '@first_name'");
      var sql = left.union(right).compile({});
      expect(sql, contains('first_name = @first_name_1'));
      expect(sql, contains("note = '@first_name'"));
    });

    test('loads the relations of its rows', () async {
      var union = _RelationsQuery().union(EmployeeQuery());
      var records = await union.get(
        _Executor(const PostgreSQLDialect(), rows: [_row]),
      );
      expect(records.single.lastName, 'loaded');
    });
  });
}
