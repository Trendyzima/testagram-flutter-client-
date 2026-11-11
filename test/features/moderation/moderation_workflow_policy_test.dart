import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/moderation/moderation_workflow_policy.dart';

void main() {
  test('appeal reason bounds use trimmed text', () {
    expect(ModerationWorkflowPolicy.validAppealReason(' too short '), isFalse);
    expect(ModerationWorkflowPolicy.validAppealReason('x' * 20), isTrue);
    expect(ModerationWorkflowPolicy.validAppealReason('x' * 800), isTrue);
    expect(ModerationWorkflowPolicy.validAppealReason('x' * 801), isFalse);
  });

  test('appeal submission rejects unauthenticated, duplicate and busy states', () {
    const reason = 'I believe the restriction was applied in error.';
    expect(ModerationWorkflowPolicy.canSubmitAppeal(
      authenticated: true, submitting: false, hasPendingAppeal: false, reason: reason,
    ), isTrue);
    expect(ModerationWorkflowPolicy.canSubmitAppeal(
      authenticated: false, submitting: false, hasPendingAppeal: false, reason: reason,
    ), isFalse);
    expect(ModerationWorkflowPolicy.canSubmitAppeal(
      authenticated: true, submitting: true, hasPendingAppeal: false, reason: reason,
    ), isFalse);
    expect(ModerationWorkflowPolicy.canSubmitAppeal(
      authenticated: true, submitting: false, hasPendingAppeal: true, reason: reason,
    ), isFalse);
  });

  test('appeal decisions require owner and pending state', () {
    expect(ModerationWorkflowPolicy.canReviewAppeal(
      isOwner: true, status: 'pending', decision: 'approved',
    ), isTrue);
    expect(ModerationWorkflowPolicy.canReviewAppeal(
      isOwner: false, status: 'pending', decision: 'approved',
    ), isFalse);
    expect(ModerationWorkflowPolicy.canReviewAppeal(
      isOwner: true, status: 'approved', decision: 'denied',
    ), isFalse);
    expect(ModerationWorkflowPolicy.canReviewAppeal(
      isOwner: true, status: 'pending', decision: 'lift_ban',
    ), isFalse);
  });

  test('report decisions require owner, open state and idle row', () {
    expect(ModerationWorkflowPolicy.canDecideReport(
      isOwner: true, status: 'open', decision: 'resolved', busy: false,
    ), isTrue);
    expect(ModerationWorkflowPolicy.canDecideReport(
      isOwner: false, status: 'open', decision: 'resolved', busy: false,
    ), isFalse);
    expect(ModerationWorkflowPolicy.canDecideReport(
      isOwner: true, status: 'resolved', decision: 'dismissed', busy: false,
    ), isFalse);
    expect(ModerationWorkflowPolicy.canDecideReport(
      isOwner: true, status: 'open', decision: 'delete_post', busy: false,
    ), isFalse);
    expect(ModerationWorkflowPolicy.canDecideReport(
      isOwner: true, status: 'open', decision: 'resolved', busy: true,
    ), isFalse);
  });

  test('audit note has a bounded maximum length', () {
    expect(ModerationWorkflowPolicy.validAuditNote('x' * 1000), isTrue);
    expect(ModerationWorkflowPolicy.validAuditNote('x' * 1001), isFalse);
  });
}
