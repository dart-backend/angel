import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

void main() {
  group('OrderBy.compile', () {
    test('compiles a plain column ascending and descending', () {
      expect(OrderBy('name').compile(), 'name ASC');
      expect(OrderBy('name', descending: true).compile(), 'name DESC');
    });

    test('compiles a qualified column', () {
      expect(OrderBy('po.id').compile(), 'po.id ASC');
    });

    test('rejects a CASE/subquery sort key', () {
      expect(
        () => OrderBy(
          "(CASE WHEN (SELECT secret FROM users WHERE role='admin') LIKE 'S3%' THEN 0 ELSE 1 END)",
        ).compile(),
        throwsArgumentError,
      );
    });

    test('rejects a stacked-statement sort key', () {
      expect(
        () => OrderBy('name; DROP TABLE users --').compile(),
        throwsArgumentError,
      );
    });

    test('rejects a quote-breakout sort key', () {
      expect(() => OrderBy("name' OR '1'='1").compile(), throwsArgumentError);
    });
  });
}
