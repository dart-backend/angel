import 'dart:collection';
import 'range_header.dart';
import 'range_header_item.dart';

/// Represents the contents of a parsed `Range` header.
class RangeHeaderImpl implements RangeHeader {
  UnmodifiableListView<RangeHeaderItem> _cached;
  final List<RangeHeaderItem> _items = [];

  RangeHeaderImpl(this.rangeUnit, [List<RangeHeaderItem> items = const []]) {
    this._items.addAll(items ?? []);
  }

  @override
  UnmodifiableListView<RangeHeaderItem> get items =>
      _cached ??= new UnmodifiableListView<RangeHeaderItem>(_items);

  @override
  final String rangeUnit;
}
