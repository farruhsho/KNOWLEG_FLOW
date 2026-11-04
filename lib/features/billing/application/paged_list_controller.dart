import 'package:flutter/foundation.dart';

/// One page fetched from a cursor-based source.
@immutable
class PageChunk<T> {
  final List<T> items;

  /// Opaque cursor for the next page (e.g. the last DocumentSnapshot).
  final Object? nextCursor;
  final bool hasMore;

  const PageChunk(this.items, {this.nextCursor, required this.hasMore});
}

typedef PageFetcher<T> = Future<PageChunk<T>> Function(Object? cursor);

/// Small cursor pagination state holder used by the transactions page.
/// Independent of Firestore so it can be unit-tested with a fake fetcher.
class PagedListController<T> extends ChangeNotifier {
  PagedListController(this._fetch);

  final PageFetcher<T> _fetch;

  final List<T> _items = [];
  List<T> get items => List.unmodifiable(_items);

  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  bool _loadedOnce = false;
  bool _disposed = false;
  int _generation = 0;

  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  Object? get error => _error;
  bool get loadedOnce => _loadedOnce;
  bool get isEmpty => _loadedOnce && _items.isEmpty && _error == null;

  /// (Re)loads from the first page.
  Future<void> refresh() async {
    _generation++;
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _error = null;
    _loading = false;
    _loadedOnce = false;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore || _disposed) return;
    final gen = _generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final chunk = await _fetch(_cursor);
      if (gen != _generation || _disposed) return;
      _items.addAll(chunk.items);
      _cursor = chunk.nextCursor;
      _hasMore = chunk.hasMore && chunk.nextCursor != null;
    } catch (e) {
      if (gen != _generation || _disposed) return;
      _error = e;
    } finally {
      if (gen == _generation && !_disposed) {
        _loading = false;
        _loadedOnce = true;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
