/// Pure presentation and navigation rules for the authenticated platform inbox.
class PlatformInboxPolicy {
  const PlatformInboxPolicy._();

  static const pageSize = 30;
  static const filters = <String>{'all', 'unread', 'like', 'reply', 'follow', 'mention', 'repost', 'payment', 'news', 'update', 'tip', 'trending'};

  static bool matchesFilter(Map<String, dynamic> message, String filter) {
    if (filter == 'all') return true;
    final unread = message.containsKey('read_at')
        ? message['read_at'] == null || message['read_at'] == ''
        : message['read'] != true;
    if (filter == 'unread') return unread;
    return (message['kind'] ?? message['type']) == filter;
  }

  static int unreadCount(Iterable<Map<String, dynamic>> messages) =>
      messages.where((message) => message.containsKey('read_at')
          ? message['read_at'] == null || message['read_at'] == ''
          : message['read'] != true).length;

  /// Only same-origin relative paths are navigable from an inbox CTA.
  /// Reject absolute URLs, protocol-relative URLs, backslashes and control chars.
  static String? safeInternalPath(dynamic value) {
    if (value is! String || value.isEmpty || !value.startsWith('/') || value.startsWith('//')) {
      return null;
    }
    if (value.contains('\\') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.contains('\u0000')) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.hasAuthority || !uri.path.startsWith('/')) {
      return null;
    }
    return uri.toString();
  }
}
