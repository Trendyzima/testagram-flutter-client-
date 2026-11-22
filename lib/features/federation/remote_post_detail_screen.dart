import 'package:material_ui/material_ui.dart';

import '../feed/feed_media_url.dart';

/// Read-only detail view for a remote object already returned by the
/// Backend-authorized unified feed or search result.
///
/// This screen deliberately does not call the local UUID-backed post detail
/// API, and does not invent remote likes, replies, reposts or author actions.
class RemotePostDetailScreen extends StatelessWidget {
  const RemotePostDetailScreen({super.key, required this.post});

  final Map<String, dynamic> post;

  String get _origin => (post['origin'] ?? '').toString().toLowerCase();

  String get _sourceLabel => switch (_origin) {
        'activitypub' => 'Fediverse · ActivityPub',
        'atproto' || 'bluesky' => 'Bluesky · AT Protocol',
        _ => 'Federated network',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = post['author'];
    final authorMap = author is Map ? author : const <String, dynamic>{};
    final sourceIdentity = authorMap['source_identity'];
    final sourceMap = sourceIdentity is Map
        ? sourceIdentity
        : const <String, dynamic>{};
    final name = (authorMap['display_name'] ??
            authorMap['username'] ??
            'Remote author')
        .toString();
    final handle = (authorMap['username'] ?? sourceMap['handle'] ?? '')
        .toString();
    final avatar = FeedMediaUrl.normalize(authorMap['avatar_url']);
    final content = (post['content'] ?? '').toString();
    final createdAt = DateTime.tryParse((post['created_at'] ?? '').toString());
    final canonicalUri = (post['canonical_uri'] ?? '').toString().trim();
    final visibility = (post['visibility'] ?? '').toString();
    final rawMedia = post['media_urls'];
    final mediaUrls = rawMedia is List
        ? rawMedia.map(FeedMediaUrl.normalize).whereType<String>().toList()
        : <String>[];
    final rawTypes = post['media_content_types'];
    final mediaTypes = rawTypes is List
        ? rawTypes.map((value) => value.toString().toLowerCase()).toList()
        : <String>[];
    final mediaHeaders = <String, String>{};
    final rawHeaders = post['media_auth_headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final url = FeedMediaUrl.normalize(entry.key);
        final authorization = entry.value.toString();
        if (url != null &&
            url.startsWith('https://') &&
            authorization.startsWith('Bearer v1.')) {
          mediaHeaders[url] = authorization;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Remote post')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sourceLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (visibility == 'public' || visibility == 'unlisted')
                const Chip(label: Text('Public')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage:
                    avatar != null && avatar.startsWith('https://')
                        ? NetworkImage(avatar)
                        : null,
                child: avatar == null || !avatar.startsWith('https://')
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    if (handle.isNotEmpty)
                      Text(
                        handle.startsWith('@') ? handle : '@$handle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 12),
            Text(
              createdAt.toLocal().toString().split('.').first,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SelectableText(
            content.isEmpty ? 'This remote post has no text content.' : content,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          for (var index = 0; index < mediaUrls.length; index++) ...[
            const SizedBox(height: 14),
            if ((index < mediaTypes.length &&
                    mediaTypes[index].startsWith('video/')) ||
                (index == 0 && post['is_video'] == true))
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Remote video preview is not available in this read-only view.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  mediaUrls[index],
                  fit: BoxFit.contain,
                  headers: mediaHeaders[mediaUrls[index]] == null
                      ? null
                      : {'Authorization': mediaHeaders[mediaUrls[index]]!},
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
          ],
          if (canonicalUri.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Canonical remote reference',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(
              canonicalUri,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Read-only remote snapshot. Testagram has not enabled an interaction or refresh contract for this object in this view.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
