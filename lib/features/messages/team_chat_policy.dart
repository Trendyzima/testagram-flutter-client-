/// Client-side display/input rules for Team Chat.
///
/// These booleans are UX hints only. The Backend must independently authorize
/// room membership, staff assignment, moderation role and every message action.
class TeamChatPolicy {
  const TeamChatPolicy._();

  static bool canShowTeamChat({
    required bool isOwner,
    required bool isRegulator,
    required bool hasActiveAssignment,
  }) =>
      isOwner || isRegulator || hasActiveAssignment;

  static bool canShowModerationControls({
    required bool isOwner,
    required bool isRegulator,
  }) =>
      isOwner || isRegulator;

  static String composeMessage(String input) => input.trim();
}
