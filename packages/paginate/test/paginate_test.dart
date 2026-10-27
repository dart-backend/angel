import 'package:angel3_paginate/angel3_paginate.dart';
import 'package:test/test.dart';

// Count-down from 100, then 101 at the end...
final List<int> data = List<int>.generate(100, (i) => 100 - i)..add(101);

void main() {
  group('cache', () {
    var cached = Paginator<int>(data),
        uncached = Paginator<int>(data, useCache: false);

    test('always cache current', () {
      expect(cached.current, cached.current);
      expect(uncached.current, uncached.current);
    });

    test('only cache prev/next if useCache != false', () {
      var cached1 = cached.current;
      cached.goToPage(4);
      var cached4 = cached.current;
      cached.goToPage(1);
      expect(cached.current, cached1);
      cached.goToPage(4);
      expect(cached.current, cached4);

      var uncached1 = uncached.current;
      uncached.goToPage(4);
      var uncached4 = uncached.current;
      uncached.goToPage(1);
      expect(uncached.current, isNot(uncached1));
      uncached.goToPage(4);
      expect(uncached.current, isNot(uncached4));
    });
  });

  test('default state', () {
    var paginator = Paginator<int>(data);
    expect(paginator.index, 0);
    expect(paginator.pageNumber, 1);
    expect(paginator.itemsPerPage, 5);
    expect(paginator.useCache, true);
    expect(paginator.canGoBack, false);
    expect(paginator.canGoForward, true);
    expect(paginator.lastPageNumber, 21);

    // Going back should do nothing
    var p = paginator.pageNumber;
    paginator.back();
    expect(paginator.pageNumber, p);
  });

  group('paginate', () {
    test('first page', () {
      var paginator = Paginator<int>(data);
      expect(paginator.pageNumber, 1);
      var r = paginator.current;
      print(r.toJson());
      expect(r.total, data.length);
      expect(r.itemsPerPage, 5);
      expect(r.previousPage, -1);
      expect(r.currentPage, 1);
      expect(r.nextPage, 2);
      expect(r.startIndex, 0);
      expect(r.endIndex, 4);
      expect(
        r.data,
        data.skip(r.startIndex as int).take(r.itemsPerPage as int).toList(),
      );
    });
  });

  test('third page', () {
    var paginator = Paginator<int>(data)..goToPage(3);
    expect(paginator.pageNumber, 3);
    var r = paginator.current;
    print(r.toJson());
    expect(r.total, data.length);
    expect(r.itemsPerPage, 5);
    expect(r.previousPage, 2);
    expect(r.currentPage, 3);
    expect(r.nextPage, 4);
    expect(r.startIndex, 10);
    expect(r.endIndex, 14);
    expect(
      r.data,
      data.skip(r.startIndex as int).take(r.itemsPerPage as int).toList(),
    );

    paginator.back();
    expect(paginator.pageNumber, 2);
  });

  test('last page', () {
    var paginator = Paginator<int>(data);
    paginator.goToPage(paginator.lastPageNumber);
    var r = paginator.current;
    expect(r.total, data.length);
    expect(r.itemsPerPage, 5);
    expect(r.previousPage, paginator.lastPageNumber - 1);
    expect(r.currentPage, paginator.lastPageNumber);
    expect(r.nextPage, -1);
    expect(r.startIndex, (paginator.lastPageNumber - 1) * 5);
    expect(r.endIndex, r.startIndex);
    expect(r.data, [data.last]);
    expect(
      r.data,
      data.skip(r.startIndex as int).take(r.itemsPerPage as int).toList(),
    );
  });

  test('dump pages', () {
    var paginator = Paginator<int>(data);
    print('${paginator.lastPageNumber} page(s) of data:');

    var pages = 0;
    while (true) {
      print('  * Page #${paginator.pageNumber}: ${paginator.current.data}');
      pages++;
      if (!paginator.canGoForward) break;
      paginator.next();
    }
    expect(pages, paginator.lastPageNumber);
  });

  test('cannot go forward from the last page', () {
    var paginator = Paginator<int>(data)..goToPage(21);
    expect(paginator.canGoForward, isFalse);
    paginator.next();
    expect(paginator.pageNumber, 21);
  });

  test('next stops at the last page of a single page', () {
    var paginator = Paginator([1, 2, 3, 4])..next();
    var page = paginator.current;
    expect(paginator.pageNumber, 1);
    expect(page.startIndex, 0);
    expect(page.endIndex, 3);
  });

  test('itemsPerPage less than 1 is an ArgumentError', () {
    expect(() => Paginator(data, itemsPerPage: 0), throwsArgumentError);
    expect(() => Paginator(data, itemsPerPage: -1), throwsArgumentError);
  });

  test('later changes to the items are not seen', () {
    var items = [1, 2, 3];
    var paginator = Paginator(items);
    expect(paginator.current.total, 3);
    items.insert(0, 0);
    expect(paginator.current.data, [1, 2, 3]);
    expect(paginator.lastPageNumber, 1);
  });

  test('a lazy iterable is read once', () {
    var reads = 0;
    var items = Iterable.generate(12, (i) {
      reads++;
      return i;
    });
    var paginator = Paginator(items)
      ..next()
      ..next();
    expect(paginator.current.data, [10, 11]);
    expect(paginator.canGoForward, isFalse);
    expect(reads, 12);
  });

  test('empty collection', () {
    var paginator = Paginator([]);
    var page = paginator.current;
    print(page.toJson());

    expect(page.total, 0);
    expect(page.previousPage, -1);
    expect(page.nextPage, -1);
    expect(page.currentPage, 1);
    expect(page.startIndex, -1);
    expect(page.endIndex, -1);
    expect(page.data, isEmpty);
    expect(paginator.canGoBack, isFalse);
    expect(paginator.canGoForward, isFalse);
  });
}
