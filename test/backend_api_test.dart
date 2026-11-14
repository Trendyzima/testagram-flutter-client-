import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  group('BackendApi', () {
    test('records registration consent through the authenticated Backend', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'recorded': true, 'email_verified': false},
          }), 200);
        }),
      );

      final result = await api.recordRegistrationConsent(
        adultConfirmed: true,
        termsAccepted: true,
        privacyAccepted: true,
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/auth/registration-consent');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect(jsonDecode(captured.body), {
        'adult_confirmed': true,
        'terms_accepted': true,
        'privacy_accepted': true,
      });
      expect((result['data'] as Map)['recorded'], isTrue);
      api.close();
    });

    test('loads trending hashtags and a cursor-paginated hashtag timeline', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': [], 'posts': [], 'has_more': false},
          }), 200);
        }),
      );

      await api.getTrendingHashtags(limit: 12);
      await api.getHashtagTimeline('#Testagram', limit: 15, cursor: 'next-page');

      expect(requests, hasLength(2));
      expect(requests[0].method, 'GET');
      expect(requests[0].url.path, '/api/hashtags/trending');
      expect(requests[0].url.queryParameters, {'limit': '12'});
      expect(requests[1].method, 'GET');
      expect(requests[1].url.path, '/api/hashtags/Testagram');
      expect(requests[1].url.queryParameters, {
        'limit': '15',
        'before': 'next-page',
      });
      expect(requests.every((request) =>
          request.headers['authorization'] == 'Bearer appwrite-session-jwt'), isTrue);
      api.close();
    });

    test('rejects invalid hashtag values and limits before sending', () {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(() => api.getTrendingHashtags(limit: 51), throwsArgumentError);
      expect(() => api.getHashtagTimeline('bad tag'), throwsArgumentError);
      expect(() => api.getHashtagTimeline(''), throwsArgumentError);
      expect(() => api.getHashtagTimeline('test', limit: 0), throwsArgumentError);
      api.close();
    });

    test('follows and unfollows normalized hashtags with authenticated requests', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'tag': 'testagram', 'is_following': request.method == 'POST'},
          }), 200);
        }),
      );

      await api.followHashtag('#Testagram');
      await api.unfollowHashtag('Testagram');

      expect(requests, hasLength(2));
      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/api/hashtags/Testagram/follow');
      expect(jsonDecode(requests[0].body), isEmpty);
      expect(requests[1].method, 'DELETE');
      expect(requests[1].url.path, '/api/hashtags/Testagram/follow');
      expect(requests.every((request) =>
          request.headers['authorization'] == 'Bearer appwrite-session-jwt'), isTrue);
      api.close();
    });

    test('rejects malformed hashtags before follow requests are sent', () {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(() => api.followHashtag('bad tag'), throwsArgumentError);
      expect(() => api.unfollowHashtag(''), throwsArgumentError);
      expect(() => api.followHashtag(List.filled(65, 'a').join()), throwsArgumentError);
      api.close();
    });

    test('publishes a canonical post with visibility and idempotency', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'id': 'post-123', 'visibility': 'public'},
          }), 201);
        }),
      );

      final response = await api.createPost(
        content: 'Hello Testagram #BuildInPublic',
        visibility: 'public',
        idempotencyKey: 'post-create-123456',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/social/posts');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect(captured.headers['idempotency-key'], 'post-create-123456');
      expect(jsonDecode(captured.body), {
        'content': 'Hello Testagram #BuildInPublic',
        'visibility': 'public',
      });
      expect((response['data'] as Map)['id'], 'post-123');
      api.close();
    });

    test('rejects invalid post content, visibility and idempotency locally', () {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(() => api.createPost(content: '  ', idempotencyKey: 'post-create-123456'),
          throwsArgumentError);
      expect(() => api.createPost(content: 'Hello', visibility: 'world',
          idempotencyKey: 'post-create-123456'), throwsArgumentError);
      expect(() => api.createPost(content: 'Hello', idempotencyKey: 'short'),
          throwsArgumentError);
      api.close();
    });

    test('waits for Data Centre replication before returning a ready upload', () async {
      var completionAttempts = 0;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/api/media/upload-intent') {
            return http.Response(jsonEncode({
              'ok': true,
              'data': {
                'key': 'users/alice/0123456789abcdef0123456789abcdef',
                'url': '/api/media/upload?key=users%2Falice%2F0123456789abcdef0123456789abcdef',
              },
            }), 201);
          }
          if (request.method == 'PUT' && request.url.path == '/api/media/upload') {
            return http.Response('', 204);
          }
          if (request.method == 'POST' && request.url.path == '/api/media/complete') {
            completionAttempts++;
            if (completionAttempts == 1) {
              return http.Response(jsonEncode({
                'ok': true,
                'data': {
                  'key': 'users/alice/0123456789abcdef0123456789abcdef',
                  'status': 'replication_pending',
                  'retry_after_ms': 1000,
                },
              }), 202);
            }
            return http.Response(jsonEncode({
              'ok': true,
              'data': {
                'key': 'users/alice/0123456789abcdef0123456789abcdef',
                'status': 'ready',
                'visibility': 'public',
                'content_type': 'image/jpeg',
                'size_bytes': 3,
              },
            }), 201);
          }
          return http.Response('{}', 404);
        }),
      );

      final asset = await api.uploadPublicImage(
        name: 'photo.jpg',
        contentType: 'image/jpeg',
        bytes: [1, 2, 3],
      );

      expect(completionAttempts, 2);
      expect(asset['status'], 'ready');
      expect(asset['size_bytes'], 3);
      api.close();
    });

    test('attaches a verified media asset to an owned main-feed post', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'key': 'media/key-1', 'post_id': 'post-1'},
          }), 200);
        }),
      );

      await api.attachPostMedia('post-1', 'media/key-1');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/media/attach');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect(jsonDecode(captured.body), {'key': 'media/key-1', 'post_id': 'post-1'});
      api.close();
    });

    test('requests private CDN media access with an authenticated Backend call', () async {
      late http.Request captured;
      final expiry = DateTime.now().toUtc().add(const Duration(minutes: 2));
      const key = 'users/alice/0123456789abcdef0123456789abcdef';
      const assertion = 'Bearer v1.payload.signature';
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'url': 'https://media.testagram.site/v1/$key',
              'authorization': assertion,
              'expires_at': expiry.toIso8601String(),
              'expires_in_seconds': 120,
              'visibility': 'private',
            },
          }), 200);
        }),
      );

      final access = await api.getPrivateMediaAccess(key);
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/media/cdn-download-url');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect(jsonDecode(captured.body), {'key': key});
      expect(access.url.toString(), 'https://media.testagram.site/v1/$key');
      expect(access.headers, {'Authorization': assertion});
      expect(access.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
      expect(access.url.hasQuery, isFalse);
      api.close();
    });

    test('accepts Appwrite owner IDs with underscores and periods', () async {
      const key = 'users/user_123.test/0123456789abcdef0123456789abcdef';
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async => http.Response(jsonEncode({
          'ok': true,
          'data': {
            'url': 'https://media.testagram.site/v1/$key',
            'authorization': 'Bearer v1.payload.signature',
            'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 2)).toIso8601String(),
            'expires_in_seconds': 120,
            'visibility': 'private',
          },
        }), 200)),
      );
      final access = await api.getPrivateMediaAccess(key);
      expect(access.headers['Authorization'], 'Bearer v1.payload.signature');
      api.close();
    });

    test('rejects malformed private media keys and unsafe CDN responses', () async {
      var calls = 0;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'url': 'https://media.testagram.site/v1/users/alice/0123456789abcdef0123456789abcdef?token=leak',
              'authorization': 'Bearer v1.payload.signature',
              'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 1)).toIso8601String(),
            },
          }), 200);
        }),
      );

      await expectLater(api.getPrivateMediaAccess('../private/object'), throwsArgumentError);
      await expectLater(
        api.getPrivateMediaAccess('users/alice/0123456789abcdef0123456789abcdef'),
        throwsA(isA<BackendApiException>()),
      );
      expect(calls, 1);
      api.close();
    });

    test('wallet methods use the authenticated native capability contract', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'ok': true, 'data': {'status': 'ok'}}), 200);
        }),
      );

      await api.getWalletBalance(currency: 'KES');
      await api.listWalletTransactions(limit: 25);
      await api.resolveWalletRecipient('@recipient_1');
      await api.transferWalletFunds(
        recipientId: '00000000-0000-4000-8000-000000000002',
        amount: '125.50',
        note: 'Thanks',
        idempotencyKey: 'wallet-transfer-key-001',
      );

      expect(requests, hasLength(4));
      expect(requests.every((request) => request.method == 'POST'), isTrue);
      expect(requests.every((request) => request.url.path == '/api/capability'), isTrue);
      expect(requests.every((request) =>
          request.headers['authorization'] == 'Bearer appwrite-session-jwt'), isTrue);
      final payloads = requests.map((request) => jsonDecode(request.body) as Map).toList();
      expect(payloads[0], {'capability': 'testagram.wallet.balance', 'input': {'currency': 'KES'}});
      expect(payloads[1], {'capability': 'testagram.wallet.transactions.list', 'input': {'limit': 25}});
      expect(payloads[2], {'capability': 'testagram.wallet.recipient.resolve', 'input': {'username': 'recipient_1'}});
      expect(payloads[3], {
        'capability': 'testagram.wallet.transfer',
        'input': {
          'recipient_id': '00000000-0000-4000-8000-000000000002',
          'amount': '125.50',
          'note': 'Thanks',
          'idempotency_key': 'wallet-transfer-key-001',
        },
      });
      api.close();
    });

    test('wallet API validates limits, recipient and idempotency locally', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(() => api.listWalletTransactions(limit: 101), throwsArgumentError);
      expect(() => api.resolveWalletRecipient('@'), throwsArgumentError);
      expect(() => api.transferWalletFunds(
        recipientId: 'recipient', amount: '10', idempotencyKey: 'short',
      ), throwsArgumentError);
      api.close();
    });

    test('loads the canonical post feed using an Appwrite JWT', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{'id': 'post-1', 'content': 'Hello Testagram'}],
              'next_cursor': 'cursor-2',
              'has_more': true,
            },
            'error': null,
          }), 200);
        }),
      );

      final response = await api.getHomeFeed(limit: 20, followingOnly: true);
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/feed/home');
      expect(captured.url.queryParameters['following_only'], 'true');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['posts'], hasLength(1));
      api.close();
    });

    test('lists post interactions through the authenticated Backend route', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': [], 'has_more': false},
          }), 200);
        }),
      );

      await api.listPostInteractions(
        '00000000-0000-4000-8000-000000000001',
        kind: 'likes',
      );
      expect(captured.method, 'GET');
      expect(captured.url.path,
          '/api/social/posts/00000000-0000-4000-8000-000000000001/interactions/likes');
      expect(captured.url.queryParameters['limit'], '100');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      api.close();
    });

    test('rejects unsupported interaction kinds and page limits locally', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(
        () => api.listPostInteractions('post-id', kind: 'quote-likes'),
        throwsArgumentError,
      );
      expect(
        () => api.listPostInteractions('post-id', kind: 'likes', limit: 101),
        throwsArgumentError,
      );
      api.close();
    });

    test('loads privacy-filtered profile posts through the authenticated API', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'posts': [{'id': 'post-1', 'content': 'Profile post'}],
              'next_cursor': 'next-post',
              'has_more': true,
            },
          }), 200);
        }),
      );
      final response = await api.getProfilePosts(
        '00000000-0000-4000-8000-000000000002',
        cursor: 'previous-post',
      );
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/social/profiles/00000000-0000-4000-8000-000000000002/posts');
      expect(captured.url.queryParameters, {'limit': '20', 'before': 'previous-post'});
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['posts'], hasLength(1));
      api.close();
    });

    test('lists profile followers with the authenticated cursor contract', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': [], 'next_cursor': 'next-page', 'has_more': true, 'kind': 'followers'},
          }), 200);
        }),
      );
      final response = await api.listProfileConnections(
        '00000000-0000-4000-8000-000000000002',
        kind: 'followers',
        cursor: 'previous-page',
      );
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/social/profiles/00000000-0000-4000-8000-000000000002/connections');
      expect(captured.url.queryParameters, {
        'kind': 'followers',
        'limit': '30',
        'cursor': 'previous-page',
      });
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['has_more'], isTrue);
      api.close();
    });

    test('resolves the current Appwrite session to a canonical Backend account', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'verified-appwrite-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': '00000000-0000-4000-8000-000000000002',
              'username': 'linked_member',
            },
          }), 200);
        }),
      );

      final profile = await api.getMyProfile();
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/me/profile');
      expect(captured.headers['authorization'], 'Bearer verified-appwrite-jwt');
      expect((profile['data'] as Map)['username'], 'linked_member');
      api.close();
    });

    test('loads a profile through the authenticated Backend route', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': '00000000-0000-4000-8000-000000000002',
              'username': 'test_user',
              'avatar_url': 'https://media.testagram.site/avatar.png',
              'is_following': false,
              'can_view_posts': false,
            },
          }), 200);
        }),
      );

      final response = await api.getProfile('00000000-0000-4000-8000-000000000002');
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/social/profiles/00000000-0000-4000-8000-000000000002');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['can_view_posts'], isFalse);
      api.close();
    });

    test('loads a privacy-filtered post detail using the Appwrite JWT', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': '00000000-0000-4000-8000-000000000001',
              'content': 'A privacy-filtered post',
              'likes_count': 3,
            },
          }), 200);
        }),
      );

      final response = await api.getPost('00000000-0000-4000-8000-000000000001');
      expect(captured.method, 'GET');
      expect(captured.url.path,
          '/api/social/posts/00000000-0000-4000-8000-000000000001');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['content'], 'A privacy-filtered post');
      api.close();
    });

    test('sends reactions only through the authenticated social API', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'is_liked': true}}), 200);
        }),
      );

      await api.reactToPost('00000000-0000-4000-8000-000000000001');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/social/posts/00000000-0000-4000-8000-000000000001/reaction');
      expect(jsonDecode(captured.body), {'emoji': '❤️'});
      expect(captured.headers['authorization'], 'Bearer jwt');
      api.close();
    });

    test('creates replies through the canonical social API', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'reply-1'}}), 201);
        }),
      );

      await api.createPostReply('post-id', 'A reply');
      expect(captured.url.path, '/api/social/posts/post-id/replies');
      expect(jsonDecode(captured.body), {'content': 'A reply'});
      api.close();
    });

    test('searches people and posts through the Backend search route', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'users': [], 'posts': []}}), 200);
        }),
      );
      await api.search(query: 'testagram', kind: 'all');
      expect(captured.url.path, '/api/search');
      expect(captured.url.queryParameters['q'], 'testagram');
      expect(captured.url.queryParameters['kind'], 'all');
      api.close();
    });

    test('creates threads through the dedicated threads endpoint', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'thread-1'}}), 201);
        }),
      );
      await api.createThread('A separate thread');
      expect(captured.url.path, '/api/threads');
      expect(jsonDecode(captured.body), {'body': 'A separate thread', 'visibility': 'public'});
      api.close();
    });

    test('lists public polls using bounded offset pagination', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'items': [], 'next_offset': 20, 'has_more': true},
          }), 200);
        }),
      );

      await api.listPolls(limit: 20, offset: 20);
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/social/polls');
      expect(captured.url.queryParameters, {'limit': '20', 'offset': '20'});
      expect(captured.headers['authorization'], 'Bearer jwt');
      api.close();
    });

    test('creates polls using the validated Backend payload', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'id': 'poll-1'}}), 201);
        }),
      );

      await api.createPoll(
        question: 'Which feature next?',
        description: 'Choose one',
        options: ['Messages', 'Communities'],
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/social/polls');
      expect(jsonDecode(captured.body), {
        'question': 'Which feature next?',
        'description': 'Choose one',
        'options': ['Messages', 'Communities'],
      });
      api.close();
    });

    test('votes on a poll using the selected option UUID', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'voted': true}}), 200);
        }),
      );

      await api.votePoll(
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000002',
      );
      expect(captured.method, 'POST');
      expect(captured.url.path,
          '/api/social/polls/00000000-0000-4000-8000-000000000001/vote');
      expect(jsonDecode(captured.body), {
        'option_id': '00000000-0000-4000-8000-000000000002',
      });
      api.close();
    });

    test('paginates notifications using the Backend cursor', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'items': [], 'next_cursor': ''}}), 200);
        }),
      );
      await api.listNotifications(limit: 30, cursor: 'opaque-cursor');
      expect(captured.url.path, '/api/social/notifications');
      expect(captured.url.queryParameters['limit'], '30');
      expect(captured.url.queryParameters['cursor'], 'opaque-cursor');
      api.close();
    });

    test('loads saved threads using the canonical thread tab and cursor', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'items': [], 'next_cursor': '', 'has_more': false}}), 200);
        }),
      );
      await api.getThreads(tab: 'saved', limit: 20, cursor: 'thread-cursor');
      expect(captured.url.path, '/api/threads');
      expect(captured.url.queryParameters['tab'], 'saved');
      expect(captured.url.queryParameters['cursor'], 'thread-cursor');
      expect(captured.headers['authorization'], 'Bearer jwt');
      api.close();
    });


    test('uploads an image through the bounded gateway and verifies its checksum', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/media/upload-intent') {
            return http.Response(jsonEncode({
              'ok': true,
              'data': {'key': 'media/key-1', 'url': '/api/media/upload?key=media%2Fkey-1'},
            }), 201);
          }
          if (request.method == 'PUT') return http.Response('', 204);
          if (request.url.path == '/api/media/complete') {
            return http.Response(jsonEncode({
              'ok': true,
              'data': {'key': 'media/key-1', 'status': 'ready', 'public_url': 'https://cdn.testagram.site/key-1'},
            }), 201);
          }
          return http.Response('unexpected request', 500);
        }),
      );

      final asset = await api.uploadPublicImage(
        name: 'photo.png',
        contentType: 'image/png',
        bytes: [1, 2, 3],
      );

      expect(asset['key'], 'media/key-1');
      expect(requests.map((request) => request.method), ['POST', 'PUT', 'POST']);
      expect(requests[0].url.path, '/api/media/upload-intent');
      expect(jsonDecode(requests[0].body), {
        'name': 'photo.png',
        'content_type': 'image/png',
        'visibility': 'public',
        'size_bytes': 3,
      });
      expect(requests[1].url.path, '/api/media/upload');
      expect(requests[1].headers['authorization'], 'Bearer jwt');
      expect(requests[1].headers['content-type'], 'image/png');
      expect(requests[1].bodyBytes, [1, 2, 3]);
      expect(jsonDecode(requests[2].body), {
        'key': 'media/key-1',
        'visibility': 'public',
        'content_type': 'image/png',
        'checksum_sha256': '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
      });
      api.close();
    });

    test('attaches only a ready media key through the thread media endpoint', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'data': {'attached': true}}), 200);
        }),
      );

      await api.attachThreadMedia('thread-1', 'media/key-1');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/threads/thread-1/media');
      expect(jsonDecode(captured.body), {'key': 'media/key-1'});
      api.close();
    });

    test('rejects unsupported image types before creating an upload intent', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        api.uploadPublicImage(name: 'bad.svg', contentType: 'image/svg+xml', bytes: [1]),
        throwsA(isA<BackendApiException>()),
      );
      api.close();
    });

    test('normalizes backend request timeouts into a readable API error', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async {
          throw TimeoutException('test timeout');
        }),
      );

      await expectLater(
        api.getHomeFeed(),
        throwsA(isA<BackendApiException>().having(
          (error) => error.message,
          'message',
          'The request timed out. Check your connection and try again.',
        )),
      );
      api.close();
    });

    test('surfaces structured Backend errors', () async {
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'jwt',
        client: MockClient((_) async => http.Response(
          jsonEncode({'error': {'code': 'AUTH_REQUIRED', 'message': 'Sign in again'}}),
          401,
        )),
      );
      await expectLater(
        api.getHomeFeed(),
        throwsA(isA<BackendApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Sign in again')),
      );
      api.close();
    });
    test('calls native Backend capabilities with the Appwrite session', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'user_id': 'account-1', 'username': 'recipient'}),
            200,
          );
        }),
      );

      final response = await api.callCapability(
        'testagram.wallet.recipient.resolve',
        input: {'username': 'recipient'},
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/capability');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect(jsonDecode(captured.body), {
        'capability': 'testagram.wallet.recipient.resolve',
        'input': {'username': 'recipient'},
      });
      expect(response['user_id'], 'account-1');
      api.close();
    });

    test('loads a single poll through the authenticated Backend route', () async {
      late http.Request captured;
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'id': '00000000-0000-4000-8000-000000000001',
              'question': 'Which feature next?',
              'options': [],
              'has_voted': false,
            },
          }), 200);
        }),
      );

      final response = await api.getPoll('00000000-0000-4000-8000-000000000001');
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/social/polls/00000000-0000-4000-8000-000000000001');
      expect(captured.headers['authorization'], 'Bearer appwrite-session-jwt');
      expect((response['data'] as Map)['question'], 'Which feature next?');
      api.close();
    });

    test('toggles thread likes, reposts and bookmarks through authenticated routes', () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUri: Uri.parse('https://api.testagram.site'),
        getJwt: () async => 'appwrite-session-jwt',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'thread_id': '00000000-0000-4000-8000-000000000001'},
          }), 200);
        }),
      );

      const threadId = '00000000-0000-4000-8000-000000000001';
      await api.toggleThreadLike(threadId);
      await api.toggleThreadRepost(threadId);
      await api.toggleThreadBookmark(threadId);

      expect(requests, hasLength(3));
      expect(requests.map((request) => request.method), everyElement('POST'));
      expect(requests.map((request) => request.url.path), [
        '/api/threads/$threadId/likes/toggle',
        '/api/threads/$threadId/reposts/toggle',
        '/api/threads/$threadId/bookmarks/toggle',
      ]);
      expect(requests.every((request) =>
          request.headers['authorization'] == 'Bearer appwrite-session-jwt'), isTrue);
      expect(requests.every((request) => request.body == '{}'), isTrue);
      expect(requests.every((request) => request.headers['content-type'] == 'application/json'), isTrue);
      api.close();
    });
  });
}
