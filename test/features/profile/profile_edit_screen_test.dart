import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/profile/profile_edit_screen.dart';

void main() {
  testWidgets('profile editor presents XClone-inspired cover, avatar and profile fields', (tester) async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'test-jwt',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: ProfileEditScreen(
        api: api,
        profile: const {
          'display_name': 'Test Member',
          'username': 'testmember',
          'bio': 'Building with Testagram',
          'website': 'https://testagram.site',
          'location': 'Nairobi, Kenya',
          'avatar_url': '',
          'cover_url': '',
          'avatar_key': '',
          'cover_key': '',
          'social_links': {'instagram': '@testmember'},
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Change cover'), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Bio'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Website'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('Website'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Social links'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('Social links'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    api.close();
  });
}
