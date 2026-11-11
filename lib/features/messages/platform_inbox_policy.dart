/// Presentation and navigation rules for the authenticated platform inbox.
///
/// This is UI policy only. Backend authorization and notification ownership
/// checks must still run for every read, mutation and CTA destination.
class PlatformInboxPolicy {
  const PlatformInboxPolicy._();

  static const pageSize = 30;
  static const filters = <String>{
    'all', 'unread', 'trending', 'payment', 'news', 'update', 'tip',
  };

  static bool matchesFilter(Map<String, dynamic> message, String filter) {
    if (filter == 'all') return true;
    if (filter == 'unread') return message['read'] != true;
    return message['type'] == filter;
  }

  static int unreadCount(Iterable<Map<String, dynamic>> messages) =>
      messages.where((message) => message['read'] != true).length;

  /// Accept only same-origin relative app paths; never navigate to an external URL.
  static String? safeInternalPath(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        !value.startsWith('/') ||
        value.startsWith('//') ||
        value.contains('\\') ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
        RegExp(r'%(?:2e|2f|5c|0[0-9a-f]|1[0-9a-f]|7f)', caseSensitive: false)
            .hasMatch(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/') ||
        uri.pathSegments.any((segment) => segment == '.' || segment == '..')) {
      return null;
    }
    return uri.toString();
  }
}
