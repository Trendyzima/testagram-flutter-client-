/// Shared route/input guards for local and ActivityPub post interactions.
///
/// These are client-side presentation safeguards only. The Backend remains the
/// authority for authentication, authorization, visibility and moderation.
class PostInteractionPolicy {
  const PostInteractionPolicy._();

  static String resolvePostId({
    String? pathPostId,
    String? postUri,
    String? postId,
  }) {
    for (final candidate in [pathPostId, postUri, postId]) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// Recognizes an HTTPS remote object URI without embedded user information.
  /// This is routing hygiene, not proof that the remote object is trustworthy.
  static bool isRemotePostId(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static String? validateComposerText(String value, {int maxLength = 5000}) {
    final text = value.trim();
    if (text.isEmpty) return 'Write something before publishing.';
    if (text.length > maxLength) {
      return 'Text exceeds the $maxLength character limit.';
    }
    return null;
  }

  static int boundedListLimit(int value, {int max = 100}) {
    final upperBound = max < 1 ? 1 : max;
    return value.clamp(1, upperBound);
  }
}
