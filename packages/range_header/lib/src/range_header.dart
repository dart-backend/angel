import 'dart:collection';
import 'parser.dart';
import 'range_header_item.dart';
import 'range_header_impl.dart';

/// Represents the contents of a parsed `Range` header.
abstract class RangeHeader {
  /// Returns an immutable list of the ranges that were parsed.
  UnmodifiableListView<RangeHeaderItem> get items;

  const factory RangeHeader(Iterable<RangeHeaderItem> items,
      {String rangeUnit}) = _ConstantRangeHeader;

  /// Eliminates any overlapping [items], sorts them, and folds them all into the most efficient representation possible.
  static UnmodifiableListView<RangeHeaderItem> foldItems(
      Iterable<RangeHeaderItem> items) {
    var out = new Set<RangeHeaderItem>();

    for (var item in items) {
      // Remove any overlapping items, consolidate them.
      while (out.any((x) => x.overlaps(item))) {
        var f = out.firstWhere((x) => x.overlaps(item));
        out.remove(f);
        item = item.consolidate(f);
      }

      out.add(item);
    }

    return new UnmodifiableListView(out.toList()..sort());
  }

  /// Attempts to parse a [RangeHeader] from its [text] representation.
  ///
  /// You can optionally pass a custom list of [allowedRangeUnits].
  /// The default is `['bytes']`.
  ///
  /// If [fold] is `true`, the items will be folded into the most compact
  /// possible representation.
  factory RangeHeader.parse(String text,
      {Iterable<String> allowedRangeUnits, bool fold: true}) {
    var tokens = scan(text, allowedRangeUnits?.toList() ?? ['bytes']);
    var parser = new Parser(tokens);
    var header = parser.parseRangeHeader();
    if (header == null) return null;
    var items = foldItems(header.items);
    return RangeHeaderImpl(header.rangeUnit, items);
  }

  /// Returns this header's range unit. Most commonly, this is `bytes`.
  String get rangeUnit;
}

class _ConstantRangeHeader implements RangeHeader {
  final Iterable<RangeHeaderItem> items_;
  final String rangeUnit;

  const _ConstantRangeHeader(this.items_, {this.rangeUnit: 'bytes'});

  @override
  UnmodifiableListView<RangeHeaderItem> get items =>
      new UnmodifiableListView(items_);
}
