/// Efficiently paginates collections of items in an object-oriented manner.
class Paginator<T> {
  final Map<int, PaginationResult<T>> _cache = {};
  PaginationResult<T>? _current;
  int _page = 0;

  /// The collection of items to be paginated, copied when the paginator is
  /// created.
  final List<T> _items;

  /// The maximum number of items to be shown per page.
  final int itemsPerPage;

  /// If `true` (default), then the results of paginations will be saved by page number.
  ///
  /// For example, you would only have to paginate page 1 once. Future calls would return a cached version.
  final bool useCache;

  /// Paginates a copy of [items], so that later changes to them are not seen.
  ///
  /// Throws an [ArgumentError] if [itemsPerPage] is less than `1`.
  Paginator(Iterable<T> items, {this.itemsPerPage = 5, this.useCache = true})
    : _items = List<T>.unmodifiable(items) {
    if (itemsPerPage < 1) {
      throw ArgumentError.value(
        itemsPerPage,
        'itemsPerPage',
        'Must be at least 1',
      );
    }
  }

  /// Returns `true` if there are more items at lesser page indices than the current one.
  bool get canGoBack => _page > 0;

  /// Returns `true` if there are more items at greater page indices than the current one.
  bool get canGoForward => _page < _lastPage() - 1;

  /// The current page index.
  int get index => _page;

  /// Returns the greatest possible page number for this collection, given the number of [itemsPerPage].
  int get lastPageNumber => _lastPage();

  /// The current page number. This is not the same as [index].
  ///
  /// This getter will return user-friendly numbers. The lowest value it will ever return is `1`.
  int get pageNumber => _page + 1;

  /// Fetches the current page. This will be cached until [back] or [next] is called.
  ///
  /// If [useCache] is `true` (default), then computations will be cached even after the page changes.
  PaginationResult<T> get current => _current ??= _getPage();

  PaginationResult<T> _computePage() {
    var len = _items.length;
    var offset = _page * itemsPerPage;
    if (offset > len) offset = len;
    var end = offset + itemsPerPage;
    if (end > len) end = len;
    var it = _items.sublist(offset, end);
    var last = _lastPage();
    return _PaginationResultImpl(
      it,
      currentPage: _page + 1,
      previousPage: _page <= 0 ? -1 : _page,
      nextPage: _page >= last - 1 ? -1 : _page + 2,
      startIndex: it.isEmpty ? -1 : offset,
      endIndex: it.isEmpty ? -1 : end - 1,
      itemsPerPage: itemsPerPage < len ? itemsPerPage : len,
      total: len,
    );
  }

  PaginationResult<T> _getPage() {
    if (useCache) {
      return _cache.putIfAbsent(_page, () => _computePage());
    } else {
      return _computePage();
    }
  }

  int _lastPage() => (_items.length + itemsPerPage - 1) ~/ itemsPerPage;

  /// Attempts to go the specified page. If it fails, then it will remain on the current page.
  ///
  /// Keep in mind - this just not be a zero-based index, but a one-based page number. The lowest
  /// allowed value is `1`.
  void goToPage(int page) {
    if (page > 0 && page <= _lastPage()) {
      _page = page - 1;
      _current = null;
    }
  }

  /// Moves the paginator back one page, if possible.
  void back() {
    if (_page > 0) {
      _page--;
      _current = null;
    }
  }

  /// Advances the paginator one page, if possible.
  void next() {
    if (canGoForward) {
      _page++;
      _current = null;
    }
  }
}

/// Stores the result of a pagination.
abstract class PaginationResult<T> {
  factory PaginationResult.fromMap(Map<String, dynamic> map) =>
      _PaginationResultImpl(
        (map['data'] as List).cast<T>(),
        currentPage: map['current_page'] as int?,
        endIndex: map['end_index'] as int?,
        itemsPerPage: map['items_per_page'] as int?,
        nextPage: map['next_page'] as int?,
        previousPage: map['previous_page'] as int?,
        startIndex: map['start_index'] as int?,
        total: map['total'] as int?,
      );

  Iterable<T> get data;

  int? get currentPage;

  int? get previousPage;

  int? get nextPage;

  int? get itemsPerPage;

  int? get total;

  int? get startIndex;

  int? get endIndex;

  Map<String, dynamic> toJson();
}

class _PaginationResultImpl<T> implements PaginationResult<T> {
  final List<T> _data;

  @override
  final int? currentPage;

  _PaginationResultImpl(
    Iterable<T> data, {
    this.currentPage,
    this.endIndex,
    this.itemsPerPage,
    this.nextPage,
    this.previousPage,
    this.startIndex,
    this.total,
  }) : _data = List<T>.unmodifiable(data);

  @override
  Iterable<T> get data => _data;

  @override
  final int? endIndex;

  @override
  final int? itemsPerPage;

  @override
  final int? nextPage;

  @override
  final int? previousPage;

  @override
  final int? startIndex;

  @override
  final int? total;

  @override
  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'items_per_page': itemsPerPage,
      'previous_page': previousPage,
      'current_page': currentPage,
      'next_page': nextPage,
      'start_index': startIndex,
      'end_index': endIndex,
      'data': data,
    };
  }
}
