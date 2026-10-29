class OrderBy {
  final String key;
  final bool descending;

  const OrderBy(this.key, {this.descending = false});

  String compile() {
    if (!_columnIdentifier.hasMatch(key)) {
      throw ArgumentError.value(
          key, 'key', 'is not a valid ORDER BY column identifier');
    }
    return descending ? '$key DESC' : '$key ASC';
  }
}

final RegExp _columnIdentifier =
    RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*(\.[A-Za-z_$][A-Za-z0-9_$]*)*$');
