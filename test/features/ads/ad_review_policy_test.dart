import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/ads/ad_review_policy.dart';
void main() {
  group('AdReviewPolicy', () {
    test('only enables review for authorized idle pending items', () {
      expect(AdReviewPolicy.canReview(authorized: true, busy: false, status: 'pending'), isTrue);
      expect(AdReviewPolicy.canReview(authorized: false, busy: false, status: 'pending'), isFalse);
      expect(AdReviewPolicy.canReview(authorized: true, busy: true, status: 'pending'), isFalse);
      expect(AdReviewPolicy.canReview(authorized: true, busy: false, status: 'approved'), isFalse);
    });
    test('reject notes must be non-empty and no longer than 500 chars', () {
      expect(AdReviewPolicy.canReject('  '), isFalse);
      expect(AdReviewPolicy.canReject('Please update the creative'), isTrue);
      expect(AdReviewPolicy.canReject(List.filled(501, 'x').join()), isFalse);
    });
    test('formats budget micros defensively', () {
      expect(AdReviewPolicy.formatBudget(2500000, 'KES'), 'KES 2.50');
      expect(AdReviewPolicy.formatBudget('bad', 'KES'), 'KES 0.00');
      expect(AdReviewPolicy.formatBudget(double.infinity, 'KES'), 'KES 0.00');
    });
  });
}
