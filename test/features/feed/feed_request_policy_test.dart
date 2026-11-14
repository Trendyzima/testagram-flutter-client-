import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/feed/feed_request_policy.dart';

void main() {
  group('FeedRequestPolicy.shouldStart', () {
    test('allows initial and pagination requests when idle and more exists', () {
      expect(
        FeedRequestPolicy.shouldStart(
          loading: false,
          hasMore: true,
          reset: false,
        ),
        isTrue,
      );
    });

    test('blocks concurrent pagination requests', () {
      expect(
        FeedRequestPolicy.shouldStart(
          loading: true,
          hasMore: true,
          reset: false,
        ),
        isFalse,
      );
    });

    test('blocks pagination after the final page', () {
      expect(
        FeedRequestPolicy.shouldStart(
          loading: false,
          hasMore: false,
          reset: false,
        ),
        isFalse,
      );
    });

    test('allows refresh to supersede an in-flight request', () {
      expect(
        FeedRequestPolicy.shouldStart(
          loading: true,
          hasMore: true,
          reset: true,
        ),
        isTrue,
      );
    });

    test('allows refresh after the feed reaches its end', () {
      expect(
        FeedRequestPolicy.shouldStart(
          loading: false,
          hasMore: false,
          reset: true,
        ),
        isTrue,
      );
    });
  });

  group('FeedRequestPolicy generations', () {
    test('increments the generation for a new reset', () {
      expect(FeedRequestPolicy.nextGeneration(4), 5);
    });

    test('rejects an older response after a reset starts', () {
      final paginationGeneration = FeedRequestPolicy.nextGeneration(4);
      final refreshGeneration =
          FeedRequestPolicy.nextGeneration(paginationGeneration);

      expect(
        FeedRequestPolicy.isCurrent(
          requestGeneration: paginationGeneration,
          currentGeneration: refreshGeneration,
        ),
        isFalse,
      );
      expect(
        FeedRequestPolicy.isCurrent(
          requestGeneration: refreshGeneration,
          currentGeneration: refreshGeneration,
        ),
        isTrue,
      );
    });
  });
}
