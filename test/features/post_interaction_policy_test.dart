import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/feed/post_interaction_policy.dart';

void main() {
  group('PostInteractionPolicy', () {
    test('prefers path ID and falls back to ActivityPub URI or ID', () {
      expect(
        PostInteractionPolicy.resolvePostId(
          pathPostId: ' local-id ',
          postUri: 'https://remote.example/objects/1',
        ),
        'local-id',
      );
      expect(
        PostInteractionPolicy.resolvePostId(
          pathPostId: ' ',
          postUri: 'https://remote.example/objects/1',
        ),
        'https://remote.example/objects/1',
      );
      expect(PostInteractionPolicy.resolvePostId(postId: 'fallback'), 'fallback');
      expect(PostInteractionPolicy.resolvePostId(), isEmpty);
    });

    test('remote IDs require HTTPS, a host, and no embedded user info', () {
      expect(PostInteractionPolicy.isRemotePostId('https://social.example/p/1'), isTrue);
      expect(PostInteractionPolicy.isRemotePostId('HTTPS://social.example/p/1'), isTrue);
      expect(PostInteractionPolicy.isRemotePostId('http://social.example/p/1'), isFalse);
      expect(PostInteractionPolicy.isRemotePostId('https:///missing-host'), isFalse);
      expect(PostInteractionPolicy.isRemotePostId('https://user@social.example/p/1'), isFalse);
      expect(PostInteractionPolicy.isRemotePostId('https://user:pass@social.example/p/1'), isFalse);
      expect(PostInteractionPolicy.isRemotePostId('not-a-url'), isFalse);
      expect(PostInteractionPolicy.isRemotePostId(''), isFalse);
    });

    test('composer validation trims text and enforces the configured limit', () {
      expect(PostInteractionPolicy.validateComposerText('   '), isNotNull);
      expect(PostInteractionPolicy.validateComposerText('  hello  '), isNull);
      expect(PostInteractionPolicy.validateComposerText('123456', maxLength: 5), isNotNull);
      expect(PostInteractionPolicy.validateComposerText('x', maxLength: 0), isNotNull);
    });

    test('list limits remain within a positive bounded range', () {
      expect(PostInteractionPolicy.boundedListLimit(-5), 1);
      expect(PostInteractionPolicy.boundedListLimit(30), 30);
      expect(PostInteractionPolicy.boundedListLimit(1000), 100);
      expect(PostInteractionPolicy.boundedListLimit(4, max: 0), 1);
    });
  });
}
