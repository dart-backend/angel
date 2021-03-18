# merge_map
Combine multiple Maps into one. Equivalent to
[Object.assign](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign)
in JS.

# Example

```dart
import "package:merge_map/merge_map.dart";

main() {
    Map map1 = {'hello': 'world'};
    Map map2 = {'foo': {'bar': 'baz', 'this': 'will be overwritten'}};
    Map map3 = {'foo': {'john': 'doe', 'this': 'overrides previous maps'}};
    Map merged = mergeMap(map1, map2, map3);

    // {hello: world, foo: {bar: baz, john: doe, this: overrides previous maps}}
}
```