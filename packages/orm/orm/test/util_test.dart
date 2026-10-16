import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

void main() {
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

    test('passes the name to replace', () {
      var sql = replacePlaceholders('@a, @b', {
        'a': 1,
        'b': 2,
      }, (n, _) => ':$n');
      expect(sql, ':a, :b');
    });
  });
}
