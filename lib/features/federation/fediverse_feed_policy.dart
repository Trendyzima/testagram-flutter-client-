import 'package:flutter/foundation.dart';

/// ActivityPub post payloads after the Backend adapter has normalized them.
typedef FediversePost = Map<String, dynamic>;

String _fediversePostKey(FediversePost post) {
  for (final candidate in [post['uri'], post['object_url'], post['id']]) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

DateTime _fediversePublishedAt(FediversePost post) =>
    DateTime.tryParse(
      '${post['published_at'] ?? post['created_at'] ?? ''}',
    ) ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

bool _isVisibleFediversePost(FediversePost post) =>
    post['deleted_at'] == null && post['tombstone'] != true;

/// Result of reconciling a refreshed server page with the reader's visible list.
///
/// Existing cards retain their order. New posts are staged until an explicit
/// user action, and tombstones remove matching cards from the visible list.
@immutable
class FediverseFeedReconciliation {
  const FediverseFeedReconciliation({
    required this.visible,
    required this.pending,
  });

  final List<FediversePost> visible;
  final List<FediversePost> pending;
}

/// Reconciles an incoming Backend-authorized ActivityPub page with visible cards.
///
/// This is presentation state only. It never grants access, performs network
/// requests, or replaces Backend authorization and deletion decisions.
FediverseFeedReconciliation reconcileFediverseFeed(
  List<FediversePost> current,
  List<FediversePost> incoming,
) {
  final incomingByKey = <String, FediversePost>{};
  final tombstoneKeys = <String>{};

  for (final post in incoming) {
    final key = _fediversePostKey(post);
    if (key.isEmpty) continue;
    if (!_isVisibleFediversePost(post)) {
      tombstoneKeys.add(key);
      continue;
    }
    incomingByKey[key] = post;
  }

  final visibleKeys = <String>{};
  final visible = <FediversePost>[];
  for (final post in current) {
    if (!_isVisibleFediversePost(post)) continue;
    final key = _fediversePostKey(post);
    if (key.isNotEmpty && tombstoneKeys.contains(key)) continue;
    if (key.isNotEmpty) visibleKeys.add(key);
    final updated = key.isEmpty ? null : incomingByKey[key];
    visible.add(updated == null ? post : <String, dynamic>{...post, ...updated});
  }

  final pendingByKey = <String, FediversePost>{};
  for (final post in incoming) {
    if (!_isVisibleFediversePost(post)) continue;
    final key = _fediversePostKey(post);
    if (key.isEmpty ||
        visibleKeys.contains(key) ||
        tombstoneKeys.contains(key)) {
      continue;
    }
    pendingByKey[key] = post;
  }

  final pending = pendingByKey.values.toList()
    ..sort(
      (a, b) => _fediversePublishedAt(b).compareTo(_fediversePublishedAt(a)),
    );
  return FediverseFeedReconciliation(visible: visible, pending: pending);
}

/// Applies staged posts only after explicit user intent, newest first.
List<FediversePost> applyPendingFediversePosts(
  List<FediversePost> current,
  List<FediversePost> pending,
) {
  final seen = current
      .map(_fediversePostKey)
      .where((key) => key.isNotEmpty)
      .toSet();
  final additions = <FediversePost>[];

  for (final post in pending) {
    if (!_isVisibleFediversePost(post)) continue;
    final key = _fediversePostKey(post);
    if (key.isEmpty || !seen.add(key)) continue;
    additions.add(post);
  }

  additions.sort(
    (a, b) => _fediversePublishedAt(b).compareTo(_fediversePublishedAt(a)),
  );
  return [...additions, ...current];
}
