import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'belongs_to_test.dart';
import 'common.dart';
import 'edge_case_test.dart';
import 'enum_and_nested_test.dart';
import 'has_many_test.dart';
import 'many_to_many_test.dart';
import 'standalone_test.dart';

void main() {
  Logger.root.onRecord.listen((rec) {
    print(rec);
    if (rec.error != null) print(rec.error);
    if (rec.stackTrace != null) print(rec.stackTrace);
  });

  group('mysql', () {
    group(
        'belongsTo',
        () => belongsToTests(createTables(['author', 'book']),
            close: dropTables));
    group(
        'edgeCase',
        () => edgeCaseTests(
            createTables(['unorthodox', 'weird_join', 'song', 'numba']),
            close: dropTables));
    group('enumAndNested',
        () => enumAndNestedTests(createTables(['has_car']), close: dropTables));
    group('hasMany',
        () => hasManyTests(createTables(['tree', 'fruit']), close: dropTables));
    // NOTE: MySQL/MariaDB do not support jsonb data type
    //group('hasMap', () => hasMapTests(createTables(['has_maps']), close: dropTables));
    // NOTE: mysql1 driver do not support CAST();
    //group('hasOne', () => hasOneTests(createTables(['legs', 'feet']), close: dropTables));
    group(
        'manyToMany',
        () => manyToManyTests(createTables(['user', 'role', 'user_role']),
            close: dropTables));
    group('standalone',
        () => standaloneTests(createTables(['car']), close: dropTables));
  });
}
