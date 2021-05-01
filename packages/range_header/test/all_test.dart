import 'package:range_header/range_header.dart';
import 'package:test/test.dart';

final Matcher throwsRangeParseException =
    throwsA(const TypeMatcher<RangeHeaderParseException>());

main() {
  group('one item', () {
    test('start and end', () {
      var r = new RangeHeader.parse('bytes 1-200');
      expect(r.items, hasLength(1));
      expect(r.items.first.start, 1);
      expect(r.items.first.end, 200);
    });

    test('start only', () {
      var r = new RangeHeader.parse('bytes 1-');
      expect(r.items, hasLength(1));
      expect(r.items.first.start, 1);
      expect(r.items.first.end, -1);
    });

    test('end only', () {
      var r = new RangeHeader.parse('bytes -200');
      print(r.items);
      expect(r.items, hasLength(1));
      expect(r.items.first.start, -1);
      expect(r.items.first.end, 200);
    });
  });

  group('multiple items', () {
    test('three items', () {
      var r = new RangeHeader.parse('bytes 1-20, 21-40, 41-60');
      print(r.items);
      expect(r.items, hasLength(3));
      expect(r.items[0].start, 1);
      expect(r.items[0].end, 20);
      expect(r.items[1].start, 21);
      expect(r.items[1].end, 40);
      expect(r.items[2].start, 41);
      expect(r.items[2].end, 60);
    });

    test('one item without end', () {
      var r = new RangeHeader.parse('bytes 1-20, 21-');
      print(r.items);
      expect(r.items, hasLength(2));
      expect(r.items[0].start, 1);
      expect(r.items[0].end, 20);
      expect(r.items[1].start, 21);
      expect(r.items[1].end, -1);
    });
  });

  group('failures', () {
    test('no start with no end', () {
      expect(new RangeHeader.parse('-'), isNull);
    });
  });

  group('exceptions', () {
    test('invalid character', () {
      expect(() => new RangeHeader.parse('!!!'), throwsRangeParseException);
    });

    test('no ranges', () {
      expect(() => new RangeHeader.parse('bytes'), throwsRangeParseException);
    });

    test('no dash after int', () {
      expect(() => new RangeHeader.parse('bytes 3'), throwsRangeParseException);
      expect(
          () => new RangeHeader.parse('bytes 3,'), throwsRangeParseException);
      expect(
          () => new RangeHeader.parse('bytes 3 24'), throwsRangeParseException);
    });

    test('no int after dash', () {
      expect(
          () => new RangeHeader.parse('bytes -,'), throwsRangeParseException);
    });
  });

  group('complete coverage', () {
    test('exception toString()', () {
      var m = new RangeHeaderParseException('hey');
      expect(m.toString(), contains('hey'));
    });
  });

  test('content-range', () {
    expect(
        new RangeHeader.parse('bytes 1-2').items[0].toContentRange(3), '1-2/3');
  });
}
