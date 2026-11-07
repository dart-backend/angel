import 'query_base.dart';
import 'query_executor.dart';
import 'query_where.dart';
import 'util.dart';

import 'package:optional/optional.dart';

/// Represents the `UNION` of two subqueries.
///
/// Values that both queries name alike are renamed in the right query, which
/// reads its SQL as MySQL does, as a union does not know its database, and
/// neither is it the reader of the driver. In a [QueryWhere.raw], it may misread
/// a string, such as of `$$it's$$`, `-- don't` or, on PostgreSQL, `'a\'`, so that
/// a placeholder after it is not renamed, which would bind the value of the left
/// query, so [compile] throws a [StateError] where one is left.
///
/// That includes most of a `@name` in a string of the right query, which is no
/// placeholder. Give the value another name in either query. One in a string it
/// misreads, such as `$$@name$$` or, on PostgreSQL, `'a\' || '@name'`, is renamed
/// instead, without an error, which changes the string.
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
        r = replacePlaceholders(r, {name: value}, (_, _) => '@$newName');
        if (_placeholderOf(name).hasMatch(r)) {
          throw StateError(
            'A union cannot tell whether "@$name" in its right query is a '
            'value, which would have the value of its left query. Give it '
            'another name in either query.',
          );
        }
      }
      substitutionValues[newName] = value;
    });

    return '($l) $selector ($r)';
  }

  /// The text of a placeholder of [name], wherever it is: not `@@name`, part
  /// of `@name1` or of `a@name`.
  static RegExp _placeholderOf(String name) => RegExp(
    '(?<![\\p{L}\\p{N}_@])@${RegExp.escape(name)}(?![\\p{L}\\p{N}_])',
    unicode: true,
  );

  /// The rows are those of [left], as [deserialize] takes them.
  @override
  Future<List<T>> parseRows(QueryExecutor executor, List<List> rows) =>
      left.parseRows(executor, rows);
}
