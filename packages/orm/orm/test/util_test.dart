import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

void main() {
  group('mapToBool', () {
    test('reads the strings of a false boolean as false', () {
      for (var value in ['0', 'f', 'F', 'false', 'FALSE']) {
        expect(mapToBool(value), isFalse, reason: value);
      }
    });

    test('reads anything else as before', () {
      for (var value in ['1', 't', 'true', 1, true]) {
        expect(mapToBool(value), isTrue, reason: '$value');
      }
      for (var value in [0, false, null]) {
        expect(mapToBool(value), isFalse, reason: '$value');
      }
    });
  });

  test('defaultDate is the start of 1970 in UTC', () {
    expect(defaultDate.isUtc, isTrue);
    expect(defaultDate.millisecondsSinceEpoch, 0);
  });

  group('replacePlaceholders', () {
    String positional(String sql, Map<String, dynamic> values) {
      var params = [];
      var result = replacePlaceholders(sql, values, (_, value) {
        params.add(value);
        return '?';
      });
      return '$result $params';
    }

    test('gives the values in the order of the placeholders', () {
      expect(
        positional('a = @b AND b = @a', {'a': 1, 'b': 2}),
        'a = ? AND b = ? [2, 1]',
      );
    });

    test('matches whole names', () {
      expect(
        positional('@name1 @name', {'name': 'x', 'name1': 'y'}),
        '? ? [y, x]',
      );
    });

    test('matches names of letters in any script', () {
      expect(
        positional('prix = @prix_unité', {'prix_unité': 3}),
        'prix = ? [3]',
      );
    });

    test('leaves a placeholder without a value', () {
      expect(positional('@a @@version @b', {'b': 1}), '@a @@version ? [1]');
    });

    test('leaves a @ in quotes as it is', () {
      expect(
        positional(
          "email = 'x@name.com' AND `@name` = @name AND n = \"@name\" "
          "AND s = 'it''s @name' AND v = @@session.time_zone",
          {'name': 1, 'session': 2},
        ),
        "email = 'x@name.com' AND `@name` = ? AND n = \"@name\" "
        "AND s = 'it''s @name' AND v = @@session.time_zone [1]",
      );
    });

    test('a backslash hides a quote, as on MySQL and MariaDB', () {
      var values = {'b': 1};
      var names = [];
      replacePlaceholders(r"x = 'a\' @b' AND c = @b", values, (name, _) {
        names.add(name);
        return '?';
      });
      expect(names, ['b']);
    });

    test('passes the name to replace', () {
      var sql = replacePlaceholders('@a, @b', {
        'a': 1,
        'b': 2,
      }, (n, _) => ':$n');
      expect(sql, ':a, :b');
    });
  });
}
