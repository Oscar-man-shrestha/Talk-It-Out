class PageResult<T> {
  const PageResult({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

PageResult<T> slicePage<T>(List<T> all, {int? limit, String? cursor}) {
  if (limit != null && limit <= 0) {
    return PageResult<T>(items: <T>[], nextCursor: null);
  }

  final parsed = int.tryParse(cursor ?? '');
  final start = parsed == null || parsed < 0 ? 0 : parsed;
  if (start >= all.length) {
    return PageResult<T>(items: <T>[], nextCursor: null);
  }

  final end = limit == null || start + limit > all.length
      ? all.length
      : start + limit;
  return PageResult<T>(
    items: List<T>.unmodifiable(all.sublist(start, end)),
    nextCursor: end < all.length ? '$end' : null,
  );
}
