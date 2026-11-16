import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/federation/remote_author_subscriptions_panel.dart';

void main() {
  testWidgets('adds a Mastodon actor and displays its pending verification state',
      (tester) async {
    var subscribed = false;
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'subscriptions': subscribed
                  ? [
                      {
                        'id': '123e4567-e89b-42d3-a456-426614174000',
                        'protocol': 'activitypub',
                        'identity': 'https://mastodon.social/users/alice',
                        'handle': 'alice@mastodon.social',
                        'verification_status': 'pending',
                        'status': 'active',
                      }
                    ]
                  : [],
            },
          }), 200);
        }
        if (request.method == 'POST') {
          subscribed = true;
          return http.Response(jsonEncode({
            'ok': true,
            'data': {'verification_status': 'pending'},
          }), 202);
        }
        return http.Response(jsonEncode({'ok': true, 'data': {'removed': true}}), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RemoteAuthorSubscriptionsPanel(api: api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Follow remote authors'), findsOneWidget);
    expect(find.text('No remote authors followed yet.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'https://mastodon.social/users/alice',
    );
    await tester.tap(find.text('Add remote author'));
    await tester.pumpAndSettle();

    expect(find.text('alice@mastodon.social'), findsOneWidget);
    expect(find.textContaining('activitypub · pending'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(jsonDecode(requests.firstWhere((request) => request.method == 'POST').body), {
      'protocol': 'activitypub',
      'identity': 'https://mastodon.social/users/alice',
    });
    expect(requests.every((request) =>
        request.headers['authorization'] == 'Bearer native-token'), isTrue);
    api.close();
  });
}
