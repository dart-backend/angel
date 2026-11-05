import 'query_base.dart';

import 'package:optional/optional.dart';

/// Represents the `UNION` of two subqueries.
class Union<T> extends QueryBase<T> {
  /// The subject(s) of this binary operation.
  final QueryBase<T> left, right;

  /// Whether this is a `UNION ALL` operation.
  final bool all;

  @override
  final String tableName;

  Union(this.left, this.right, {this.all = false, String? tableName})
    : tableName = tableName ?? left.tableName;

  @override
  List<String> get fields => left.fields;

  @override
  Optional<T> deserialize(List row) => left.deserialize(row);

  @override
  String compile(
    Set<String> trampoline, {
    bool includeTableName = false,
    String? preamble,
    bool withFields = true,
  }) {
    var selector = all == true ? 'UNION ALL' : 'UNION';
    var t1 = Set<String>.from(trampoline);
    var t2 = Set<String>.from(trampoline);
    var l = left.compile(t1, includeTableName: includeTableName);
    var r = right.compile(t2, includeTableName: includeTableName);

    // The two queries name their values apart from each other's only, so a
    // name both use is renamed in [r], which would otherwise be given the
    // value of [l].
    substitutionValues
      ..clear()
      ..addAll(left.substitutionValues);
    right.substitutionValues.forEach((name, value) {
      var newName = name;
      // Neither query's name, so that no other placeholder is renamed too.
      for (
        var n = 1;
        substitutionValues.containsKey(newName) ||
            (newName != name && right.substitutionValues.containsKey(newName));
        n++
      ) {
        newName = '${name}_$n';
      }
      if (newName != name) {
        r = r.replaceAll(
          RegExp('@${RegExp.escape(name)}(?![A-Za-z0-9_])'),
          '@$newName',
        );
      }
      substitutionValues[newName] = value;
    });

    return '($l) $selector ($r)';
  }
}
