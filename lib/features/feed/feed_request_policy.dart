/// Pure request-lifecycle policy for the canonical Backend feed client.
///
/// The Backend owns pagination and returns an opaque next_cursor. This
/// policy deliberately does not construct database-specific cursor filters.
class FeedRequestPolicy {
  const FeedRequestPolicy._();

  /// A reset may supersede an in-flight request; pagination may not overlap.
  static bool shouldStart({
    required bool loading,
    required bool hasMore,
    required bool reset,
  }) {
    if (reset) return true;
    return !loading && hasMore;
  }

  /// A reset advances the generation so older responses become stale.
  static int nextGeneration(int current) => current + 1;

  static bool isCurrent({
    required int requestGeneration,
    required int currentGeneration,
  }) =>
      requestGeneration == currentGeneration;
}
