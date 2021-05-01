import 'dart:math';
import 'package:quiver_hashcode/hashcode.dart';

/// Represents an individual range, with an optional start index and optional end index.
class RangeHeaderItem implements Comparable<RangeHeaderItem> {
  /// The index at which this chunk begins. May be `-1`.
  final int start;

  /// The index at which this chunk ends. May be `-1`.
  final int end;

  const RangeHeaderItem([this.start = -1, this.end = -1]);

  /// Joins two items together into the largest possible range.
  RangeHeaderItem consolidate(RangeHeaderItem other) {
    if (!(other.overlaps(this)))
      throw new ArgumentError('The two ranges do not overlap.');
    return new RangeHeaderItem(min(start, other.start), max(end, other.end));
  }

  @override
  int get hashCode => hash2(start, end);

  @override
  bool operator ==(other) =>
      other is RangeHeaderItem && other.start == start && other.end == end;

  bool overlaps(RangeHeaderItem other) {
    if (other.start <= start) {
      return other.end < start;
    } else if (other.start > start) {
      return other.start <= end;
    }
    return false;
  }

  @override
  int compareTo(RangeHeaderItem other) {
    if (other.start > start) {
      return -1;
    } else if (other.start == start) {
      if (other.end == end) {
        return 0;
      } else if (other.end < end) {
        return 1;
      } else {
        return -1;
      }
    } else if (other.start < start) {
      return 1;
    } else {
      return -1;
    }
  }

  @override
  String toString() {
    if (start > -1 && end > -1)
      return '$start-$end';
    else if (start > -1)
      return '$start-';
    else
      return '-$end';
  }

  /// Creates a representation of this instance suitable for a `Content-Range` header.
  ///
  /// This can only be used if the user request only one range. If not, send a
  /// `multipart/byteranges` response.
  ///
  /// Please adhere to the standard!!!
  /// http://httpwg.org/specs/rfc7233.html

  String toContentRange([int totalSize]) {
    // var maxIndex = totalSize != null ? (totalSize - 1).toString() : '*';
    var s = start > -1 ? start : 0;

    if (end == -1) {
      if (totalSize == null) {
        throw new UnsupportedError(
            'If the end of this range is unknown, `totalSize` must not be null.');
      } else {
        // if (end == totalSize - 1) {
        return '$s-${totalSize - 1}/$totalSize';
      }
    }

    return '$s-$end/$totalSize';
  }
}
