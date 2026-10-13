import 'dart:collection';

/// A superclass in another library, which imports `dart:collection` without
/// a prefix.
class Base {
  final HashSet<int> ids;

  Base(this.ids);
}
