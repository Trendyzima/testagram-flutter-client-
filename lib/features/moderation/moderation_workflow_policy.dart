/// Client-side UX guards for appeals and report-review forms.
///
/// This is not an authorization boundary. The Backend must re-check role,
/// status, ownership, duplicate submissions and all input limits atomically.
class ModerationWorkflowPolicy {
  const ModerationWorkflowPolicy._();

  static bool validAppealReason(String value) {
    final length = value.trim().length;
    return length >= 20 && length <= 800;
  }

  static bool canSubmitAppeal({
    required bool authenticated,
    required bool submitting,
    required bool hasPendingAppeal,
    required String reason,
  }) =>
      authenticated &&
      !submitting &&
      !hasPendingAppeal &&
      validAppealReason(reason);

  static bool canReviewAppeal({
    required bool isOwner,
    required String status,
    required String decision,
  }) =>
      isOwner &&
      status == 'pending' &&
      const {'approved', 'denied'}.contains(decision);

  static bool canDecideReport({
    required bool isOwner,
    required String status,
    required String decision,
    required bool busy,
  }) =>
      isOwner &&
      !busy &&
      status == 'open' &&
      const {'resolved', 'dismissed'}.contains(decision);

  static bool validAuditNote(String value) => value.trim().length <= 1000;
}
