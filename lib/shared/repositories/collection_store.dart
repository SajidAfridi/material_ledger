/// The persistence boundary for a single collection of [T].
///
/// This is the one and only seam between the app's domain/state layer and
/// wherever data actually lives. Every provider talks to a [CollectionStore];
/// none of them know or care whether that is local storage, Firestore, or an
/// ASP.NET REST API. Swapping the backend = providing a different
/// implementation from [Storage] — no provider, model, or UI code changes.
///
/// The current implementation ([LocalCollectionStore]) is synchronous because
/// the prototype hydrates from an already-loaded `SharedPreferences`. The method
/// shapes are intentionally minimal so a remote adapter can implement them by
/// caching the last snapshot for [readAll] and pushing writes in [writeAll]
/// (see docs/ARCHITECTURE.md, "Swapping the backend").
abstract interface class CollectionStore<T> {
  /// The whole collection, newest-state-wins. Returns `[]` when empty/unset.
  List<T> readAll();

  /// Replace the whole collection. The single write path — easy to map onto a
  /// batched Firestore write or a `PUT /api/{collection}`.
  Future<void> writeAll(List<T> items);

  /// Whether the collection has ever been written (drives first-run seeding).
  bool get isSeeded;
}
