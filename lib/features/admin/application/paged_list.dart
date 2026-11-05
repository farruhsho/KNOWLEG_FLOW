import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_firebase.dart';

typedef PageLoader<T> = Future<AdminPage<T>> Function(
    DocumentSnapshot<Map<String, dynamic>>? after);

class PagedState<T> {
  final List<T> items;
  final bool loading;
  final bool hasMore;
  final Object? error;

  /// `true` once the first page has been attempted.
  final bool started;

  const PagedState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.error,
    this.started = false,
  });

  bool get isInitialLoading => loading && items.isEmpty;
  bool get isEmpty => started && !loading && error == null && items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    bool? loading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    bool? started,
  }) =>
      PagedState<T>(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
        started: started ?? this.started,
      );
}

/// Cursor-paginated list (FB-17). Loads the first page on creation.
///
/// The empty state is created as `PagedState<T>()`, never `const
/// PagedState()`: a const instance cannot carry the type parameter and is
/// inferred as `PagedState<Never>`, whose `copyWith(items: List<T>)` then
/// throws a TypeError on the first non-empty page.
class PagedListNotifier<T> extends StateNotifier<PagedState<T>> {
  PagedListNotifier(this._load) : super(PagedState<T>()) {
    loadMore();
  }

  final PageLoader<T> _load;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _generation = 0;

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _load(_cursor);
      if (!mounted || gen != _generation) return;
      _cursor = page.cursor;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        loading: false,
        hasMore: page.hasMore,
        started: true,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(loading: false, error: e, started: true);
    }
  }

  Future<void> refresh() async {
    _generation++;
    _cursor = null;
    state = PagedState<T>();
    await loadMore();
  }

  /// Retries after an error without discarding loaded items.
  Future<void> retry() async {
    if (state.items.isEmpty) return refresh();
    state = state.copyWith(clearError: true, hasMore: true);
    await loadMore();
  }

  /// Local update after an edit, so the list does not need a full reload.
  void replaceWhere(bool Function(T item) test, T Function(T item) update) {
    state = state.copyWith(items: [
      for (final i in state.items) test(i) ? update(i) : i,
    ]);
  }

  void removeWhere(bool Function(T item) test) {
    state = state.copyWith(items: state.items.where((i) => !test(i)).toList());
  }
}
