import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show BytesBuilder;
import 'dart:math';
import 'package:async/async.dart';
import 'package:charcode/ascii.dart';
import 'range_header.dart';

/// A [StreamTransformer] that uses a parsed [RangeHeader] and transforms an input stream
/// into one compatible with the `multipart/byte-ranges` specification.
class RangeHeaderTransformer
    extends StreamTransformerBase<List<int>, List<int>> {
  final RangeHeader header;
  final String boundary, mimeType;
  final int totalLength;

  RangeHeaderTransformer(this.header, this.mimeType, this.totalLength,
      {String boundary})
      : this.boundary = boundary ?? _randomString() {
    if (header == null || header.items.isEmpty) {
      throw new ArgumentError('`header` cannot be null or empty.');
    }
  }

  /// Computes the content length that will be written to a response, given a stream of the given [totalFileSize].
  int computeContentLength(int totalFileSize) {
    int len = 0;

    for (var item in header.items) {
      if (item.start == -1) {
        if (item.end == -1) {
          len += totalFileSize;
        } else {
          //len += item.end + 1;
          len += item.end + 1;
        }
      } else if (item.end == -1) {
        len += totalFileSize - item.start;
        //len += totalFileSize - item.start - 1;
      } else {
        len += item.end - item.start;
      }

      // Take into consideration the fact that delimiters are written.
      len += utf8.encode('--$boundary\r\n').length;
      len += utf8.encode('Content-Type: $mimeType\r\n').length;
      len += utf8
          .encode(
              'Content-Range: ${header.rangeUnit} ${item.toContentRange(totalLength)}/$totalLength\r\n\r\n')
          .length;
      len += 2; // CRLF
    }

    len += utf8.encode('--$boundary--\r\n').length;

    return len;
  }

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) {
    var ctrl = new StreamController<List<int>>();

    new Future(() async {
      var index = 0;
      var enqueued = new Queue<List<int>>();
      var q = new StreamQueue(stream);

      Future<List<int>> absorb(int length) async {
        var out = new BytesBuilder();

        while (out.length < length) {
          var remaining = length - out.length;

          while (out.length < length && enqueued.isNotEmpty) {
            remaining = length - out.length;
            var blob = enqueued.removeFirst();

            if (blob.length > remaining) {
              enqueued.addFirst(blob.skip(remaining).toList());
              blob = blob.take(remaining).toList();
            }

            out.add(blob);
            index += blob.length;
          }

          if (out.length < length && await q.hasNext) {
            var blob = await q.next;
            remaining = length - out.length;

            if (blob.length > remaining) {
              enqueued.addFirst(blob.skip(remaining).toList());
              blob = blob.take(remaining).toList();
            }

            out.add(blob);
            index += blob.length;
          }

          // If we get this far, and the stream is EMPTY, the user requested
          // too many bytes.
          if (out.length < length && enqueued.isEmpty && !(await q.hasNext)) {
            throw new StateError(
                'The range denoted is bigger than the size of the input stream.');
          }
        }

        return out.takeBytes();
      }

      for (var item in header.items) {
        var chunk = new BytesBuilder();

        // Skip until we reach the start index.
        while (index < item.start) {
          var remaining = item.start - index;
          await absorb(remaining);
        }

        // Next, absorb until we reach the end.
        if (item.end == -1) {
          while (enqueued.isNotEmpty) chunk.add(enqueued.removeFirst());
          while (await q.hasNext) chunk.add(await q.next);
        } else {
          var remaining = item.end - index;
          chunk.add(await absorb(remaining));
        }

        // Next, write the boundary and data.
        ctrl.add(utf8.encode('--$boundary\r\n'));
        ctrl.add(utf8.encode('Content-Type: $mimeType\r\n'));
        ctrl.add(utf8.encode(
            'Content-Range: ${header.rangeUnit} ${item.toContentRange(totalLength)}/$totalLength\r\n\r\n'));
        ctrl.add(chunk.takeBytes());
        ctrl.add(const [$cr, $lf]);

        // If this range was unbounded, don't bother looping any further.
        if (item.end == -1) break;
      }

      ctrl.add(utf8.encode('--$boundary--\r\n'));

      ctrl.close();
    }).catchError(ctrl.addError);

    return ctrl.stream;
  }
}

var _rnd = new Random();
String _randomString(
    {int length: 32,
    String validChars:
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'}) {
  var len = _rnd.nextInt((length - 10)) + 10;
  var buf = new StringBuffer();

  while (buf.length < len)
    buf.writeCharCode(validChars.codeUnitAt(_rnd.nextInt(validChars.length)));

  return buf.toString();
}
