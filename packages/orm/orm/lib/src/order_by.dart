import 'identifier.dart';

class OrderBy {
  final String key;
  final bool descending;

  const OrderBy(this.key, {this.descending = false});

  String compile() {
    checkIdentifier(key, 'key', 'ORDER BY column');
    return descending ? '$key DESC' : '$key ASC';
  }
}
