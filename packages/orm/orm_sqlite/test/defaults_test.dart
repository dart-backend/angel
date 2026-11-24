import 'package:test/test.dart';

import 'common.dart';
import 'models/stamped.dart';

/// The defaults of `@Column(defaultValue: ...)`, of SQL and of values.
void main() {
  for (var backend in backends) {
    group(backend.name, () {
      late TestDatabase db;

      setUp(() async => db = await backend.open());
      tearDown(() => db.close());

      test('an insert without them gets the defaults', () async {
        var before = DateTime.now().toUtc().subtract(
          const Duration(seconds: 2),
        );
        var stamped = (await (StampedQuery()..values.name = 'a').insert(
          db.executor,
        )).value;
        expect(stamped.code, 'n/a');
        expect(stamped.label, 'plain');
        expect(stamped.seenAt, isNotNull);
        expect(
          stamped.seenAt!.isAfter(before),
          isTrue,
          reason: '${stamped.seenAt}',
        );
      });

      test('the columns have them', () async {
        var columns = {
          for (var c in await db.select("PRAGMA table_info('stampeds')"))
            c['name']: c['dflt_value'],
        };
        expect(columns['code'], "'n/a'");
        expect(columns['label'], "'plain'");
        expect(columns['seen_at'], isNotNull);
      });
    });
  }
}
