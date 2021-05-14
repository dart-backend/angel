# angel3_merge_map
[![version](https://img.shields.io/badge/pub-v2.12.4-brightgreen)](https://pub.dartlang.org/packages/angel3_merge_map)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/merge_map/LICENSE)

Combine multiple Maps into one. Equivalent to
[Object.assign](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign)
in JS.

# Example

```dart
import "package:angel3_merge_map/angel3_merge_map.dart";

void main() {
    Map map1 = {'hello': 'world'};
    Map map2 = {'foo': {'bar': 'baz', 'this': 'will be overwritten'}};
    Map map3 = {'foo': {'john': 'doe', 'this': 'overrides previous maps'}};
    Map merged = mergeMap(map1, map2, map3);

    // {hello: world, foo: {bar: baz, john: doe, this: overrides previous maps}}
}
```