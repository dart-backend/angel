import 'package:angel3_orm_test/angel3_orm_test.dart';
import 'package:logging/logging.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:test/test.dart';
import 'common.dart';

void main() {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog);

  //group('performance',
  //    () => performanceTests(pg(['performance']), close: closePg));

  group('postgresql', () {
    group('belongsTo',
        () => belongsToTests(pg(['author', 'book']), close: closePg));
    group('customExpr',
        () => customExprTests(pg(['custom_expr']), close: closePg));
    group(
        'edgeCase',
        () => edgeCaseTests(pg(['unorthodox', 'weird_join', 'song', 'numba']),
            close: closePg));
    group('enumAndNested',
        () => enumAndNestedTests(pg(['has_car']), close: closePg));
    group('hasMany', () => hasManyTests(pg(['tree', 'fruit']), close: closePg));
    group('hasMap', () => hasMapTests(pg(['has_map']), close: closePg));
    group('hasOne', () => hasOneTests(pg(['leg', 'foot']), close: closePg));
    group(
        'manyToMany',
        () =>
            manyToManyTests(pg(['user', 'role', 'user_role']), close: closePg));
    group('standalone', () => standaloneTests(pg(['car']), close: closePg));
    group('join',
        () => joinTests(pg(['person', 'person_order']), close: closePg));
  });
}
