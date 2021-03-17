import 'package:test/test.dart';
import 'list_test.dart' as list;
import 'match_test.dart' as match;
import 'misc_test.dart' as misc;
import 'value_test.dart' as value;

main() {
  group('list', list.main);
  group('match', match.main);
  group('value', value.main);
  misc.main();
}
