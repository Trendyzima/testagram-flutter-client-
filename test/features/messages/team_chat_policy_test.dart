import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/messages/team_chat_policy.dart';

void main() {
  test('team chat display requires owner, regulator or active assignment', () {
    expect(TeamChatPolicy.canShowTeamChat(
      isOwner: true, isRegulator: false, hasActiveAssignment: false,
    ), isTrue);
    expect(TeamChatPolicy.canShowTeamChat(
      isOwner: false, isRegulator: true, hasActiveAssignment: false,
    ), isTrue);
    expect(TeamChatPolicy.canShowTeamChat(
      isOwner: false, isRegulator: false, hasActiveAssignment: true,
    ), isTrue);
    expect(TeamChatPolicy.canShowTeamChat(
      isOwner: false, isRegulator: false, hasActiveAssignment: false,
    ), isFalse);
  });

  test('moderation controls are shown only for owner or regulator', () {
    expect(TeamChatPolicy.canShowModerationControls(
      isOwner: false, isRegulator: false,
    ), isFalse);
    expect(TeamChatPolicy.canShowModerationControls(
      isOwner: true, isRegulator: false,
    ), isTrue);
    expect(TeamChatPolicy.canShowModerationControls(
      isOwner: false, isRegulator: true,
    ), isTrue);
  });

  test('message composer trims outer whitespace only', () {
    expect(TeamChatPolicy.composeMessage('  ship it  '), 'ship it');
    expect(TeamChatPolicy.composeMessage('  \n '), isEmpty);
    expect(TeamChatPolicy.composeMessage('line 1\nline 2'), 'line 1\nline 2');
  });
}
