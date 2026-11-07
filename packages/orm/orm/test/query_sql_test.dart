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
/// Records the rows it is given to parse.
class _RowsQuery extends EmployeeQuery {
  _RowsQuery(this.fields);

  @override
  final List<String> fields;

  final parsed = <List>[];

  @override
  Optional<Employee> deserialize(List row) {
    parsed.add(row);
    return Optional.empty();
  }
}

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
        "CASE WHEN pg_input_is_valid(t.data::jsonb->>'at', 'timestamptz') "
        "THEN (t.data::jsonb->>'at')::timestamptz END < @prop",
      );
      expect(query.substitutionValues, {'prop': dt});
    });

    test('as a map or a list names its column once', () {
      json.data['a'].asMap!.contains({'x': 1});
      expect(
        json.compile(),
        "NULLIF(data::jsonb->'a', 'null')::jsonb @> @prop::jsonb",
      );
    });

    test('nested, is a property of the property', () {
      json.data['a'].asMap!['b'].asString!.equals('x');
      expect(
        json.compile(),
        "NULLIF(data::jsonb->'a', 'null')::jsonb->>'b' = @prop",
      );
    });

    test('as a string names the values of isIn apart from its name', () {
      json.data['a'].asString!.isIn(['x']);
      expect(json.compile(), "data::jsonb->>'a' IN (@prop_in_value)");
      expect(query.substitutionValues, {'prop_in_value': 'x'});
    });

    test('with a backslash in its key is an escape string', () {
      json.data[r"a\'b"].isNotNull;
      expect(json.compile(), r"data::jsonb->>E'a\\''b' IS NOT NULL");
    });

    test('with a backslash keeps the placeholders after it apart', () {
      // A second key gives a later quote to take as the end of the first.
      json.data[r'a\'].asString!.equals('x');
      json.data['b'].asString!.equals('y');
      var names = <String>[];
      replacePlaceholders(json.compile(), query.substitutionValues, (name, _) {
        names.add(name);
        return '?';
      });
      expect(names, ['prop', 'prop1']);
    });

    test('with a backslash is renamed in a union', () {
      var right = EmployeeQuery();
      var rightJson = _JsonWhere(right);
      rightJson.data[r'a\'].asString!.equals('x');
      rightJson.data['b'].asString!.equals('y');
      right.where!.raw(rightJson.compile());
      var left = EmployeeQuery()..where!.firstName.equals('z');
      left.substitutionValues['prop'] = 'left';
      var sql = left.union(right).compile({});
      expect(sql, contains('= @prop_1'));
      expect(sql, isNot(contains('= @prop ')));
    });

    test('checks null of the value, not of the type it is read as', () {
      json.data['n'].asInt!.isNull;
      json.data['d'].asDouble!.isNotNull;
      json.data['at'].asDateTime!.isNull;
      expect(
        json.compile(tableName: 't'),
        "t.data::jsonb->>'n' IS NULL AND t.data::jsonb->>'d' IS NOT NULL "
        "AND t.data::jsonb->>'at' IS NULL",
      );
    });

    test('as a date with its parts checks null of the value alone', () {
      json.data['at'].asDateTime!
        ..isNotNull
        ..year.equals(2020);
      expect(
        json.compile(),
        "data::jsonb->>'at' IS NOT NULL AND EXTRACT(YEAR FROM CASE WHEN "
        "pg_input_is_valid(data::jsonb->>'at', 'timestamptz') THEN "
        "(data::jsonb->>'at')::timestamptz END) = 2020",
      );
    });

    test("has a ' in its key escaped", () {
      json.data["x' OR '1'='1"].isNotNull;
      expect(json.compile(), "data::jsonb->>'x'' OR ''1''=''1' IS NOT NULL");
    });
  });

  test('isIn and isNotIn of no values on a part of a date', () {
    query.where!.createdAt
      ..year.isIn(const [])
      ..second.isNotIn(const []);
    expect(query.where!.compile(), 'FALSE AND TRUE');
    query = EmployeeQuery();
    query.where!.createdAt
      ..year.isIn(const [2020])
      ..second.equals(5);
    expect(
      query.where!.compile(tableName: 'e'),
      'EXTRACT(YEAR FROM e.created_at) IN (2020) AND '
      'FLOOR(EXTRACT(SECOND FROM e.created_at)) = 5',
    );
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
      expect(sql, contains('RETURNING employees.*) SELECT '));
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
          'WITH angel3_written as (DELETE FROM employees WHERE (tableoid, ctid) IN '
          '(WITH angel3_picked AS MATERIALIZED (SELECT tableoid, ctid FROM '
          'employees WHERE last_name = @last_name ORDER BY salary DESC LIMIT 1 '
          'OFFSET 2 FOR UPDATE OF employees) SELECT * FROM angel3_picked) '
          'RETURNING ',
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
      expect(executor.queries[0], endsWith(' LIMIT 1 OFFSET 2 FOR UPDATE'));
      expect(executor.queries[1], 'DELETE FROM employees WHERE id IN (3)');
    });

    test('on MySQL deletes nothing when no row matches', () async {
      var executor = _Executor(const MySQLDialect());
      expect(await query.delete(executor), isEmpty);
      expect(executor.queries, hasLength(1));
    });

    test('without a limit has no ORDER BY', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row]);
      var q = EmployeeQuery()..orderBy('salary');
      await q.delete(executor);
      expect(executor.queries[1], 'DELETE FROM employees WHERE id IN (3)');
    });

    test(
      'of relations deletes the rows it selected, not by conditions',
      () async {
        var executor = _Executor(const PostgreSQLDialect(), rows: [_row]);
        var q = _RelationsQuery()..where!.firstName.equals('x');
        await q.delete(executor);
        expect(executor.queries.last, 'DELETE FROM employees WHERE id IN (3)');
      },
    );

    test('returns a row a join repeats once', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row, _row, _row]);
      var deleted = await (EmployeeQuery()..crossJoin('other')).delete(
        executor,
      );
      expect(deleted, hasLength(1));
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
          'DELETE FROM employees WHERE (tableoid, ctid) IN (SELECT '
          'employees.tableoid, employees.ctid FROM employees  LEFT JOIN '
          'companies a0 ON employees.company_id=a0.id WHERE '
          'employees.last_name = @last_name)',
        );
      });
    });

    test('with a GROUP BY is an error, on either database', () {
      query.groupBy('salary');
      for (var dialect in const [PostgreSQLDialect(), MySQLDialect()]) {
        expect(query.delete(_Executor(dialect)), throwsStateError);
      }
    });
  });

  group('a predicate that replaces another', () {
    test('drops its value, for any predicate', () {
      for (var replace in <void Function()>[
        () => query.where!.firstName.equals('y'),
        () => query.where!.firstName.like('y%'),
        () => query.where!.firstName.isBetween('a', 'b'),
        () => query.where!.firstName.isNotBetween('a', 'b'),
        () => query.where!.firstName.isIn(['y', 'z']),
        () => query.where!.firstName.isNotIn(['y']),
        () => query.where!.firstName.isIn(const []),
        () => query.where!.firstName.isNotIn(const []),
        () => query.where!.firstName.isNull,
        () => query.where!.firstName.isNotNull,
      ]) {
        query = EmployeeQuery();
        // Each from each of the others, as they bind differently.
        for (var first in <void Function()>[
          () => query.where!.firstName.equals('x'),
          () => query.where!.firstName.isBetween('c', 'd'),
          () => query.where!.firstName.isIn(['v', 'w']),
        ]) {
          query = EmployeeQuery();
          first();
          replace();
          var sql = query.compile({});
          for (var name in query.substitutionValues.keys) {
            expect(sql, contains('@$name'));
          }
          expect(
            RegExp(r'@(\w+)').allMatches(sql).map((m) => m[1]),
            unorderedEquals(query.substitutionValues.keys),
          );
        }
      }
    });

    test('of a JSON property as a string too', () {
      json.data['a'].asString!
        ..equals('x')
        ..isIn(const []);
      expect(json.compile(), 'FALSE');
      expect(query.substitutionValues, isEmpty);
    });

    test('leaves those of other builders', () {
      query.where!.lastName.equals('kept');
      query.where!.firstName
        ..equals('x')
        ..isNull;
      expect(query.substitutionValues, {'last_name': 'kept'});
    });
  });

  group('an insert of a query with conditions', () {
    test('is given only the values it uses', () async {
      for (var dialect in const [PostgreSQLDialect(), MySQLDialect()]) {
        var executor = _Executor(dialect);
        var q = EmployeeQuery()
          ..where!.firstName.equals('other')
          ..where!.createdAt.lessThan(DateTime(2020))
          ..orWhere((w) => w.lastName.isIn(['a', 'b']))
          ..values.lastName = 'new';
        await q.insert(executor);
        expect(executor.values.single.keys, [
          q.values.parameterNameOf(q, 'last_name'),
        ]);
      }
    });

    test('keeps the values of a join', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var joined = EmployeeQuery(parent: query)..where!.firstName.equals('j');
      query
        ..where!.lastName.equals('dropped')
        ..join(joined, 'id', 'id')
        ..values.salary = 1.0;
      await query.insert(executor);
      expect(executor.values.single.values, contains('j'));
      expect(executor.values.single.values, isNot(contains('dropped')));
    });

    test('keeps a value set by hand, for the driver to name', () async {
      var executor = _Executor(const PostgreSQLDialect());
      query.substitutionValues['by_hand'] = 1;
      query.values.lastName = 'new';
      await query.insert(executor);
      expect(executor.values.single, contains('by_hand'));
    });

    test('leaves the query as it was', () async {
      var q = EmployeeQuery()
        ..where!.firstName.equals('other')
        ..values.lastName = 'new';
      await q.insert(_Executor(const PostgreSQLDialect()));
      expect(q.substitutionValues.values, contains('other'));
    });
  });

  group('the rows a statement wrote', () {
    test(
      'are read from another name, so that the table is not hidden',
      () async {
        var executor = _Executor(const PostgreSQLDialect());
        var q = EmployeeQuery()
          ..values.lastName = 'new'
          ..selfJoin('employees', 'id', 'id', alias: 'm');
        await q.update(executor);
        var sql = executor.queries.single;
        expect(
          sql,
          startsWith('WITH angel3_written as (UPDATE employees SET '),
        );
        expect(
          sql,
          contains(
            ' FROM angel3_written AS employees  LEFT JOIN employees m ON '
            'employees.id=m.id',
          ),
        );
      },
    );

    test('have no cross join, on either database', () async {
      var pg = _Executor(const PostgreSQLDialect());
      await (EmployeeQuery()
            ..values.lastName = 'new'
            ..crossJoin('other'))
          .update(pg);
      var select = pg.queries.single.split(') RETURNING ').last;
      expect(select, isNot(contains('CROSS JOIN')));

      var my = _Executor(const MySQLDialect(), rows: [_row]);
      await (EmployeeQuery()
            ..values.lastName = 'new'
            ..crossJoin('other'))
          .update(my);
      expect(my.queries[0], contains('CROSS JOIN other'));
      expect(my.queries.last, isNot(contains('CROSS JOIN')));
    });

    test('on MySQL have a left join of any type', () async {
      var my = _Executor(const MySQLDialect(), rows: [_row]);
      await (EmployeeQuery()
            ..values.lastName = 'new'
            ..join('other', 'id', 'id'))
          .update(my);
      expect(my.queries[0], contains(' INNER JOIN other '));
      expect(my.queries.last, contains(' LEFT JOIN other '));
    });
  });

  group('an offset without a limit', () {
    test('has a limit, which MySQL and MariaDB require', () {
      expect(
        (EmployeeQuery()..offset(2)).compile({}),
        endsWith(' LIMIT 9223372036854775807 OFFSET 2'),
      );
    });

    test('with a limit is as it was', () {
      var q = EmployeeQuery()
        ..limit(1)
        ..offset(2);
      expect(q.compile({}), endsWith(' LIMIT 1 OFFSET 2'));
    });
  });

  group('an update on MySQL', () {
    test('of an id selects the row by its new id', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row]);
      var q = EmployeeQuery()
        ..where!.id.equals(3)
        ..values.id = '7';
      await q.update(executor);
      var name = q.values.parameterNameOf(q, 'id');
      expect(executor.queries[1], endsWith(' WHERE id IN (3)'));
      expect(executor.queries[2], endsWith(' WHERE employees.id = @$name'));
    });

    test('of no id keeps the columns of its joins', () async {
      var q = _RowsQuery(const ['first_name', 'last_name'])
        ..values.lastName = 'new'
        ..leftJoin('other', 'id', 'id', additionalFields: const ['name']);
      await q.update(
        _Executor(
          const MySQLDialect(),
          rows: [
            ['first', 'old', 'joined'],
          ],
        ),
      );
      expect(q.parsed.single, ['first', 'new', 'joined']);
    });

    test('of no id and no fields keeps each row', () async {
      var q = _RowsQuery(const [])..values.lastName = 'new';
      await q.update(
        _Executor(
          const MySQLDialect(),
          rows: [
            [1, 'a'],
          ],
        ),
      );
      expect(q.parsed.single, [1, 'a']);
    });

    test('of no id locks the rows it selects', () async {
      var executor = _Executor(const MySQLDialect());
      var q = _NoIdQuery()..values.lastName = 'new';
      await q.update(executor);
      expect(executor.queries.first, endsWith(' FOR UPDATE'));
    });
  });

  group('skipLocked', () {
    test('on PostgreSQL skips locked rows of the limit', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..limit(1)
        ..skipLocked();
      await q.update(executor);
      expect(
        executor.queries.single,
        contains(' LIMIT 1 FOR UPDATE OF employees SKIP LOCKED) SELECT * '),
      );
    });

    test('on MySQL skips locked rows', () async {
      var executor = _Executor(const MySQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..limit(1)
        ..skipLocked();
      await q.update(executor);
      expect(executor.queries.single, endsWith(' FOR UPDATE SKIP LOCKED'));
    });

    test('on a delete skips locked rows, on either database', () async {
      var pg = _Executor(const PostgreSQLDialect());
      await (EmployeeQuery()
            ..limit(1)
            ..skipLocked())
          .delete(pg);
      expect(
        pg.queries.single,
        contains(' FOR UPDATE OF employees SKIP LOCKED)'),
      );
      var my = _Executor(const MySQLDialect());
      await (EmployeeQuery()
            ..limit(1)
            ..skipLocked())
          .delete(my);
      expect(my.queries.first, endsWith(' FOR UPDATE SKIP LOCKED'));
    });

    test('applies without a limit', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await (EmployeeQuery()..skipLocked()).delete(executor);
      expect(executor.queries.single, contains(' SKIP LOCKED)'));
    });

    test('is an error of a join PostgreSQL cannot lock', () {
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..rightJoin('other', 'id', 'id')
        ..skipLocked();
      var executor = _Executor(const PostgreSQLDialect());
      expect(q.update(executor), throwsStateError);
      expect(q.delete(executor), throwsStateError);
    });

    test('on MySQL is an error of a query that selects no id', () {
      var executor = _Executor(const MySQLDialect());
      var q = _NoIdQuery()
        ..values.lastName = 'new'
        ..skipLocked();
      expect(q.update(executor), throwsStateError);
      expect(q.delete(executor), throwsStateError);
    });

    test('has no effect on a select', () {
      var q = EmployeeQuery()..skipLocked();
      expect(q.compile({}), isNot(contains('LOCKED')));
    });
  });

  test('a limit on PostgreSQL locks its rows, and reads them once', () async {
    var executor = _Executor(const PostgreSQLDialect());
    await (EmployeeQuery()..limit(1)).delete(executor);
    expect(
      executor.queries.single,
      contains(
        'IN (WITH angel3_picked AS MATERIALIZED (SELECT tableoid, ctid FROM '
        'employees LIMIT 1 FOR UPDATE OF employees) SELECT * FROM angel3_picked)',
      ),
    );
  });

  group('a query with a group by', () {
    setUp(() {
      query.groupBy('salary');
      query.values.lastName = 'new';
    });

    test('cannot be updated', () {
      for (var dialect in const [PostgreSQLDialect(), MySQLDialect()]) {
        expect(query.update(_Executor(dialect)), throwsStateError);
      }
    });

    test('cannot be inserted', () {
      expect(
        () => query.insert(_Executor(const PostgreSQLDialect())),
        throwsStateError,
      );
    });
  });

  group('the rows selected first are locked', () {
    test('by an update on MySQL', () async {
      var executor = _Executor(const MySQLDialect());
      await (EmployeeQuery()..values.lastName = 'new').update(executor);
      expect(executor.queries.single, 'SELECT id FROM employees FOR UPDATE');
    });

    test('by a delete on PostgreSQL, of this table alone', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await (EmployeeQuery()..leftJoin('other', 'id', 'id')).delete(executor);
      expect(executor.queries.first, endsWith(' FOR UPDATE OF employees'));
    });

    test('not by a delete on PostgreSQL of a join that adds rows', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await (EmployeeQuery()..rightJoin('other', 'id', 'id')).delete(executor);
      expect(executor.queries.first, isNot(contains('FOR UPDATE')));
    });
  });

  group('an update on MySQL of many rows', () {
    test('runs in parts', () async {
      var executor = _Executor(
        const MySQLDialect(),
        rows: [
          for (var i = 1; i <= 1500; i++) [i, ..._row.skip(1)],
        ],
      );
      await (EmployeeQuery()..values.lastName = 'new').update(executor);
      expect(
        executor.queries.where((q) => q.startsWith('UPDATE')),
        hasLength(2),
      );
    });

    test('binds an id that is not an int, each once', () async {
      var row = ['a-uuid', ..._row.skip(1)];
      var executor = _Executor(const MySQLDialect(), rows: [row, row]);
      var q = EmployeeQuery()..values.lastName = 'new';
      await q.update(executor);
      expect(executor.queries[1], endsWith(' WHERE id IN (@id_key0)'));
      expect(executor.values[1], containsPair('id_key0', 'a-uuid'));
      expect(q.substitutionValues, isNot(contains('id_key0')));
    });
  });

  group('a cross join', () {
    test('qualifies the columns of a select', () {
      var sql = (EmployeeQuery()..crossJoin('other')).compile({});
      expect(sql, startsWith('SELECT employees.id, '));
      expect(sql, endsWith(' FROM employees CROSS JOIN other'));
    });

    test('picks the rows of an update', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..crossJoin('other');
      await q.update(executor);
      expect(
        executor.queries.single,
        contains(
          'WHERE (tableoid, ctid) IN (SELECT employees.tableoid, '
          'employees.ctid FROM employees CROSS JOIN other) RETURNING ',
        ),
      );
    });

    test('deletes the rows it selected, by id', () async {
      var executor = _Executor(const PostgreSQLDialect(), rows: [_row, _row]);
      await (EmployeeQuery()..crossJoin('other')).delete(executor);
      expect(executor.queries.last, 'DELETE FROM employees WHERE id IN (3)');
    });

    test('of a query that selects no id is an error', () {
      for (var dialect in const [PostgreSQLDialect(), MySQLDialect()]) {
        var q = _NoIdQuery()..crossJoin('other');
        expect(q.delete(_Executor(dialect)), throwsStateError);
      }
      var q = _NoIdQuery()
        ..values.lastName = 'new'
        ..crossJoin('other');
      expect(q.update(_Executor(const MySQLDialect())), throwsStateError);
    });
  });

  group('a join that adds rows', () {
    test('has only the rows of this table when it picks rows', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..rightJoin('other', 'id', 'id', alias: 'o')
        ..where!.firstName.equals('x');
      await q.update(executor);
      var sql = executor.queries.single;
      expect(
        sql,
        contains(
          'WHERE (employees.first_name = @first_name) AND '
          'employees.tableoid IS NOT NULL) RETURNING ',
        ),
      );
      expect(
        sql,
        contains(' FROM angel3_written AS employees  LEFT JOIN other o '),
      );
    });

    test('has only the rows of this table when it deletes', () async {
      var executor = _Executor(const MySQLDialect());
      await (EmployeeQuery()..rightJoin('other', 'id', 'id')).delete(executor);
      expect(
        executor.queries.first,
        endsWith(' WHERE employees.id IS NOT NULL FOR UPDATE'),
      );
    });

    test('has only the rows it wrote on an insert', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..fullOuterJoin('other', 'id', 'id');
      await q.insert(executor);
      expect(
        executor.queries.single,
        contains(' FROM angel3_written AS employees  LEFT JOIN other a0 '),
      );
    });
  });

  group('update under a limit', () {
    setUp(() {
      query.values.lastName = 'new';
      query
        ..orderBy('salary', descending: true)
        ..limit(1);
    });

    test('picks the rows with the joins of the query', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..join('companies', 'company_id', 'id', alias: 'c')
        ..orderBy('c.name')
        ..limit(1);
      await q.update(executor);
      expect(
        executor.queries.single,
        contains(
          'WHERE (tableoid, ctid) IN (WITH angel3_picked AS MATERIALIZED (SELECT '
          'employees.tableoid, employees.ctid FROM employees  INNER JOIN '
          'companies c ON employees.company_id=c.id ORDER BY c.name ASC LIMIT 1 '
          'FOR UPDATE OF employees) SELECT * FROM angel3_picked) RETURNING ',
        ),
      );
    });

    test('on MySQL picks the rows with the joins of the query', () async {
      var executor = _Executor(const MySQLDialect());
      var q = EmployeeQuery()
        ..values.lastName = 'new'
        ..join('companies', 'company_id', 'id', alias: 'c')
        ..orderBy('c.name')
        ..limit(1);
      await q.update(executor);
      expect(
        executor.queries.first,
        'SELECT employees.id FROM employees  INNER JOIN companies c ON '
        'employees.company_id=c.id ORDER BY c.name ASC LIMIT 1 FOR UPDATE',
      );
    });

    test('orders the rows by the SQL of an expression', () async {
      var executor = _Executor(const PostgreSQLDialect());
      var q = EmployeeQuery()
        ..values.firstName = 'new'
        ..expressions['last_name'] = 'UPPER(first_name)'
        ..orderBy('last_name', descending: true)
        ..limit(1);
      await q.update(executor);
      expect(
        executor.queries.single,
        contains(
          'ORDER BY (UPPER(first_name)) DESC LIMIT 1 FOR UPDATE OF employees)',
        ),
      );
    });

    group('without a limit', () {
      EmployeeQuery joined() => EmployeeQuery()
        ..values.lastName = 'new'
        ..where!.firstName.equals('x')
        ..join('companies', 'company_id', 'id', alias: 'c');

      test('on PostgreSQL updates only the rows of a join', () async {
        var executor = _Executor(const PostgreSQLDialect());
        await joined().update(executor);
        expect(
          executor.queries.single,
          contains(
            'WHERE (tableoid, ctid) IN (SELECT employees.tableoid, '
            'employees.ctid FROM employees  INNER JOIN companies c ON '
            'employees.company_id=c.id WHERE employees.first_name = ',
          ),
        );
      });

      test('on MySQL updates only the rows of a join, each once', () async {
        var executor = _Executor(const MySQLDialect(), rows: [_row, _row]);
        await joined().update(executor);
        expect(
          executor.queries[0],
          startsWith('SELECT employees.id FROM employees  INNER JOIN '),
        );
        expect(executor.queries[1], endsWith(' WHERE id IN (3)'));
      });

      test('a left join picks the rows, as its alias may be named', () async {
        var executor = _Executor(const PostgreSQLDialect());
        var q = EmployeeQuery()
          ..values.lastName = 'new'
          ..leftJoin('companies', 'company_id', 'id', alias: 'c')
          ..where!.raw('c.deleted = false');
        await q.update(executor);
        expect(
          executor.queries.single,
          contains(
            'WHERE (tableoid, ctid) IN (SELECT employees.tableoid, '
            'employees.ctid FROM employees  LEFT JOIN companies c ON '
            'employees.company_id=c.id WHERE (c.deleted = false)) RETURNING ',
          ),
        );
      });

      test('with an order by a column a join may have too', () async {
        var executor = _Executor(const MySQLDialect());
        var q = EmployeeQuery()
          ..values.lastName = 'new'
          ..join('companies', 'company_id', 'id', alias: 'c')
          ..orderBy('first_name', descending: true)
          ..orderBy('c.name')
          ..orderBy('other')
          ..limit(1);
        await q.update(executor);
        expect(
          executor.queries.first,
          endsWith(
            ' ORDER BY employees.first_name DESC, c.name ASC, other ASC LIMIT 1 '
            'FOR UPDATE',
          ),
        );
      });

      test('with an order by an alias', () async {
        var executor = _Executor(const MySQLDialect());
        var q = EmployeeQuery()
          ..values.lastName = 'new'
          ..aliases['first_name'] = 'given'
          ..orderBy('given')
          ..limit(1);
        await q.update(executor);
        expect(
          executor.queries.first,
          endsWith(' ORDER BY first_name ASC LIMIT 1 FOR UPDATE'),
        );
      });

      test('on MySQL, selecting no id, has no join that leaves a row out', () {
        var q = _NoIdQuery()
          ..values.lastName = 'new'
          ..join('companies', 'company_id', 'id');
        expect(q.update(_Executor(const MySQLDialect())), throwsStateError);
      });

      test('on MySQL, selecting no id, has a left join', () async {
        var executor = _Executor(const MySQLDialect());
        var q = _NoIdQuery()
          ..values.lastName = 'new'
          ..leftJoin('companies', 'company_id', 'id');
        await q.update(executor);
        expect(
          executor.queries.last,
          'UPDATE employees SET last_name=@last_name',
        );
      });
    });

    test('on PostgreSQL picks the first rows in order', () async {
      var executor = _Executor(const PostgreSQLDialect());
      await query.update(executor);
      expect(
        executor.queries.single,
        contains(
          'WHERE (tableoid, ctid) IN (WITH angel3_picked AS MATERIALIZED (SELECT '
          'tableoid, ctid FROM employees ORDER BY salary DESC LIMIT 1 FOR UPDATE '
          'OF employees) SELECT * FROM angel3_picked) RETURNING ',
        ),
      );
    });

    test('on MySQL picks the first rows in order', () async {
      var executor = _Executor(const MySQLDialect(), rows: [_row]);
      await query.update(executor);
      expect(
        executor.queries.first,
        'SELECT id FROM employees ORDER BY salary DESC LIMIT 1 FOR UPDATE',
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

  group('the names of a join', () {
    test('of a table may be quoted, but not qualified', () {
      query.join('"order"', '"key"', '"id"', alias: '"o"');
      expect(
        query.compile({}),
        contains('INNER JOIN "order" "o" ON employees."key"="o"."id"'),
      );
      for (var join in <void Function()>[
        () => query.join('t', 'employees.id', 'id'),
        () => query.join('t', 'id', 'a0.id'),
        () => query.join('t', 'id', 'id', alias: 'a.b'),
        () => query.join('t', 'id', 'id', additionalFields: ['a.b']),
      ]) {
        expect(join, throwsArgumentError);
      }
    });

    test('of a query are plain, as they name its columns', () {
      for (var join in <void Function()>[
        () => query.join(EmployeeQuery(), 'id', '"id"'),
        () => query.join(EmployeeQuery(), 'id', 'id', alias: '"o"'),
        () =>
            query.join(EmployeeQuery(), 'id', 'id', additionalFields: ['"id"']),
      ]) {
        expect(join, throwsArgumentError);
      }
    });

    test('of a query may have a quoted key of this table', () {
      query.join(EmployeeQuery(), '"key"', 'id', alias: 'o');
      expect(query.compile({}), contains('ON employees."key"=o.o_id'));
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

    test('rejects a key that would not make a parameter', () {
      for (var key in ['"order"', '`order`', 't.col', r'a$b', '1a', '']) {
        var values = MapQueryValues()..values[key] = 1;
        expect(
          () => values.compileForUpdate(query),
          throwsArgumentError,
          reason: key,
        );
      }
    });

    test('keeps a column the query does not select', () {
      query.values.lastName = 'new';
      var narrowed = _NoIdQuery();
      var values = MapQueryValues()..values['first_name'] = 'x';
      expect(values.compileForUpdate(narrowed), 'SET first_name=@first_name');
    });
  });

  group('a union', () {
    group('with a value of the same name in its right query', () {
      late EmployeeQuery left, right;

      setUp(() {
        left = EmployeeQuery()..where!.firstName.equals('a');
        right = EmployeeQuery();
        right.substitutionValues['first_name'] = 'b';
      });

      test('renames it', () {
        right.where!.raw('first_name = @first_name');
        var sql = left.union(right).compile({});
        expect(sql, contains('first_name = @first_name_1'));
      });

      for (var raw in [
        r"note <> $$it's$$ AND first_name = @first_name AND c <> 'd'",
        "note <> 'x' -- don't\n AND first_name = @first_name AND c <> 'd'",
        "note <> 'x' /* don't */ AND first_name = @first_name AND c <> 'd'",
      ]) {
        test('rejects one it cannot rename: $raw', () {
          right.where!.raw(raw);
          expect(() => left.union(right).compile({}), throwsStateError);
        });
      }

      test('rejects one in a string, which it cannot tell apart', () {
        right.where!.raw("note = '@first_name'");
        expect(() => left.union(right).compile({}), throwsStateError);
      });

      test('accepts another name, a longer one and a system variable', () {
        right.where!.raw(
          'a = @first_name AND b = @first_name1 AND c = @@first_name',
        );
        right.substitutionValues['first_name1'] = 'c';
        var sql = left.union(right).compile({});
        expect(sql, contains('a = @first_name_1'));
        expect(sql, contains('b = @first_name1'));
        expect(sql, contains('c = @@first_name'));
      });
    });

    test('renames a value after an escape string in a raw condition', () {
      var left = EmployeeQuery()..where!.firstName.equals('a');
      var right = EmployeeQuery()..where!.firstName.equals('b');
      right.where!.raw(
        r"note = E'a\\' AND first_name <> @first_name AND c = 'd'",
      );
      var sql = left.union(right).compile({});
      expect(sql, contains('first_name <> @first_name_1'));
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
