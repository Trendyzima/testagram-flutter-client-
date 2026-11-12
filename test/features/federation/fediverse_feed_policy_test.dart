import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/federation/fediverse_feed_policy.dart';

Map<String, dynamic> post(
  String uri,
  String publishedAt, {
  String? content,
}) =>
    {
      'uri': uri,
      'published_at': publishedAt,
      if (content != null) 'content': content,
    };

void main() {
  group('reconcileFediverseFeed', () {
    test('keeps visible order and stages new posts during refresh', () {
      final current = [
        post('old-a', '2026-10-10T10:00:00Z'),
        post('old-b', '2026-10-09T10:00:00Z'),
      ];
      final result = reconcileFediverseFeed(current, [
        post('newest', '2026-10-12T10:00:00Z'),
        post('old-a', '2026-10-10T10:00:00Z', content: 'edited'),
      ]);

      expect(result.visible.map((p) => p['uri']), ['old-a', 'old-b']);
      expect(result.visible.first['content'], 'edited');
      expect(result.pending.map((p) => p['uri']), ['newest']);
    });

    test('deduplicates incoming posts and excludes tombstones', () {
      final result = reconcileFediverseFeed([], [
        post('same', '2026-10-12T10:00:00Z'),
        post('same', '2026-10-12T10:00:00Z', content: 'latest duplicate'),
        {
          'uri': 'deleted',
          'published_at': '2026-10-12T11:00:00Z',
          'tombstone': true,
        },
      ]);

      expect(result.pending, hasLength(1));
      expect(result.pending.single['uri'], 'same');
      expect(result.pending.single['content'], 'latest duplicate');
    });

    test('removes a visible card when the refreshed page contains its tombstone', () {
      final current = [
        post('keep', '2026-10-10T10:00:00Z'),
        post('remove', '2026-10-09T10:00:00Z'),
      ];

      final result = reconcileFediverseFeed(current, [
        {
          'uri': 'remove',
          'published_at': '2026-10-09T10:00:00Z',
          'tombstone': true,
        },
      ]);

      expect(result.visible.map((p) => p['uri']), ['keep']);
      expect(result.pending, isEmpty);
    });

    test('uses object URL and ID when the canonical URI is absent', () {
      final result = reconcileFediverseFeed([], [
        {
          'uri': ' ',
          'object_url': 'https://remote.example/objects/1',
          'created_at': '2026-10-12T10:00:00Z',
        },
        {
          'id': 'post-2',
          'created_at': '2026-10-11T10:00:00Z',
        },
      ]);

      expect(result.pending, hasLength(2));
      expect(result.pending.first['object_url'], 'https://remote.example/objects/1');
    });
  });

  group('applyPendingFediversePosts', () {
    test('applies pending items newest-first without duplicating visible rows', () {
      final result = applyPendingFediversePosts(
        [post('visible', '2026-10-10T10:00:00Z')],
        [
          post('older-new', '2026-10-11T10:00:00Z'),
          post('newest', '2026-10-12T10:00:00Z'),
          post('visible', '2026-10-09T10:00:00Z'),
        ],
      );

      expect(result.map((p) => p['uri']), ['newest', 'older-new', 'visible']);
    });

    test('does not apply tombstones or posts without stable identity', () {
      final result = applyPendingFediversePosts([], [
        {
          'uri': 'deleted',
          'published_at': '2026-10-12T10:00:00Z',
          'deleted_at': '2026-10-12T11:00:00Z',
        },
        {'published_at': '2026-10-12T10:00:00Z'},
      ]);

      expect(result, isEmpty);
    });
  });
}
