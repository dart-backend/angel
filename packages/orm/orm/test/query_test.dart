import 'package:test/test.dart';

import '../example/main.dart';

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
}
