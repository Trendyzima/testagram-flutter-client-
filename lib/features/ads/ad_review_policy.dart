/// Presentation rules for ad review controls.
/// The server remains responsible for authorization and review state transitions.
class AdReviewPolicy {
  const AdReviewPolicy._();
  static const filters = <String>['pending', 'approved', 'rejected', 'all'];
  static bool canReview({required bool authorized, required bool busy, required String status}) =>
      authorized && !busy && status == 'pending';
  static bool canReject(String note) => note.trim().isNotEmpty && note.trim().length <= 500;
  static String formatBudget(dynamic micros, String currency) {
    final parsed = micros is num ? micros.toDouble() : double.tryParse('$micros') ?? 0;
    final value = parsed.isFinite ? parsed : 0;
    return currency + ' ' + (value / 1000000).toStringAsFixed(2);
  }
}
