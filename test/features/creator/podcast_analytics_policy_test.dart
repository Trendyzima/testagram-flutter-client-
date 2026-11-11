import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/creator/podcast_analytics_policy.dart';
void main() {
  group('PodcastAnalyticsPolicy', () {
    test('locks only explicit locked records', () {
      expect(PodcastAnalyticsPolicy.isLocked({'is_locked': true}), isTrue);
      expect(PodcastAnalyticsPolicy.isLocked({'is_locked': false}), isFalse);
      expect(PodcastAnalyticsPolicy.isLocked(null), isFalse);
    });
    test('parses counts and finite amounts defensively', () {
      expect(PodcastAnalyticsPolicy.asCount('42'), 42);
      expect(PodcastAnalyticsPolicy.asCount('bad'), 0);
      expect(PodcastAnalyticsPolicy.asAmount('12.5'), 12.5);
      expect(PodcastAnalyticsPolicy.asAmount('NaN'), 0);
    });
    test('formats durations', () {
      expect(PodcastAnalyticsPolicy.formatDuration(0), '0m');
      expect(PodcastAnalyticsPolicy.formatDuration(125), '2m');
      expect(PodcastAnalyticsPolicy.formatDuration(3660), '1h 1m');
    });
  });
}
