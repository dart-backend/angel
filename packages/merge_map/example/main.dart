import 'package:angel3_merge_map/angel3_merge_map.dart';

void main() {
  // ignore: omit_local_variable_types
  Map map1 = {'hello': 'world'};

  // ignore: omit_local_variable_types
  Map map2 = {
    'foo': {'bar': 'baz', 'this': 'will be overwritten'}
  };

  // ignore: omit_local_variable_types
  Map map3 = {
    'foo': {'john': 'doe', 'this': 'overrides previous maps'}
  };
  var merged = mergeMap([map1, map2, map3]);
  print(merged);

  // {hello: world, foo: {bar: baz, john: doe, this: overrides previous maps}}
}
