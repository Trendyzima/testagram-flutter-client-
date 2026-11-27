import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/app_config.dart';
import 'package:testagram/core/auth/native_auth_client.dart';
import 'package:testagram/features/auth/auth_screen.dart';
import 'package:testagram/features/auth/identity_application_store.dart';

class _MemoryIdentityStorage implements IdentityApplicationSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('TESTAGRAM_STAGING_AUTH_EMAIL');
  const password = String.fromEnvironment('TESTAGRAM_STAGING_AUTH_PASSWORD');

  testWidgets(
    'native login UI persists only refresh securely, restores after client restart and revokes on logout',
    (tester) async {
      final baseUri = AppConfig.backendOrigin;
      expect(baseUri.scheme, 'https');
      expect(baseUri.host, isNotEmpty);
      expect(
        {'api.testagram.site', 'testagram.site', 'www.testagram.site', 'media.testagram.site', 'cdn.testagram.site'}
            .contains(baseUri.host.toLowerCase().replaceFirst(RegExp(r'\\.
        isFalse,
        reason: 'Android native auth staging test must never target a canonical production host',
      );
      expect(email, isNotEmpty, reason: 'Dedicated verified staging identity email is required');
      expect(password, isNotEmpty, reason: 'Dedicated verified staging identity password is required');

      final signedIn = ValueNotifier<bool>(false);
      var client = NativeAuthClient(baseUri: baseUri);
      await client.clearSession();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: signedIn,
              builder: (context, isSignedIn, _) {
                if (isSignedIn) {
                  return const Scaffold(
                    body: Center(child: Text('Authenticated staging shell')),
                  );
                }
                return AuthScreen(
                  authClient: client,
                  onSignedIn: () => signedIn.value = true,
                  enableIdentityRegistration: false,
                  identityApplicationStore: IdentityApplicationStore(
                    storage: _MemoryIdentityStorage(),
                  ),
                );
              },
            ),
          ),
        );

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), email);
        await tester.enterText(fields.at(1), password);
        final signInButton = find.widgetWithText(FilledButton, 'Sign in');
        await tester.ensureVisible(signInButton);
        await tester.tap(signInButton);

        for (var attempt = 0; attempt < 180 && !signedIn.value; attempt++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(
          signedIn.value,
          isTrue,
          reason: 'Flutter AuthScreen must complete real Backend login and profile validation',
        );
        expect(find.text('Authenticated staging shell'), findsOneWidget);

        final originalAccess = await client.accessToken();
        expect(originalAccess, isNotNull);
        expect(originalAccess!.length, greaterThanOrEqualTo(32));

        // Closing the first client simulates process loss. The only credential
        // that survives is the opaque refresh token in Android secure storage.
        client.close();
        client = NativeAuthClient(baseUri: baseUri);
        final restoredAccess = await client.accessToken();
        expect(restoredAccess, isNotNull);
        expect(restoredAccess, isNot(originalAccess),
            reason: 'A restored session must rotate the persisted refresh credential');

        final profile = await http.get(
          baseUri.resolve('/api/me/profile'),
          headers: {'Authorization': 'Bearer $restoredAccess'},
        );
        expect(profile.statusCode, 200);
        final profileEnvelope = jsonDecode(profile.body) as Map<String, dynamic>;
        expect(profileEnvelope['ok'], isTrue);

        await client.signOut();
        expect(await client.accessToken(), isNull,
            reason: 'Sign-out must clear the persisted refresh token');
        final revokedProfile = await http.get(
          baseUri.resolve('/api/me/profile'),
          headers: {'Authorization': 'Bearer $restoredAccess'},
        );
        expect(revokedProfile.statusCode, 401,
            reason: 'The Backend must reject the access token after Flutter logout');
      } finally {
        try {
          await client.signOut();
        } catch (_) {
          await client.clearSession();
        }
        client.close();
        signedIn.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
), '')),
        isFalse,
        reason: 'Android native auth staging test must never target a canonical production host',
      );
      expect(email, isNotEmpty, reason: 'Dedicated verified staging identity email is required');
      expect(password, isNotEmpty, reason: 'Dedicated verified staging identity password is required');

      final signedIn = ValueNotifier<bool>(false);
      var client = NativeAuthClient(baseUri: baseUri);
      await client.clearSession();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: signedIn,
              builder: (context, isSignedIn, _) {
                if (isSignedIn) {
                  return const Scaffold(
                    body: Center(child: Text('Authenticated staging shell')),
                  );
                }
                return AuthScreen(
                  authClient: client,
                  onSignedIn: () => signedIn.value = true,
                  enableIdentityRegistration: false,
                  identityApplicationStore: IdentityApplicationStore(
                    storage: _MemoryIdentityStorage(),
                  ),
                );
              },
            ),
          ),
        );

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), email);
        await tester.enterText(fields.at(1), password);
        final signInButton = find.widgetWithText(FilledButton, 'Sign in');
        await tester.ensureVisible(signInButton);
        await tester.tap(signInButton);

        for (var attempt = 0; attempt < 180 && !signedIn.value; attempt++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(
          signedIn.value,
          isTrue,
          reason: 'Flutter AuthScreen must complete real Backend login and profile validation',
        );
        expect(find.text('Authenticated staging shell'), findsOneWidget);

        final originalAccess = await client.accessToken();
        expect(originalAccess, isNotNull);
        expect(originalAccess!.length, greaterThanOrEqualTo(32));

        // Closing the first client simulates process loss. The only credential
        // that survives is the opaque refresh token in Android secure storage.
        client.close();
        client = NativeAuthClient(baseUri: baseUri);
        final restoredAccess = await client.accessToken();
        expect(restoredAccess, isNotNull);
        expect(restoredAccess, isNot(originalAccess),
            reason: 'A restored session must rotate the persisted refresh credential');

        final profile = await http.get(
          baseUri.resolve('/api/me/profile'),
          headers: {'Authorization': 'Bearer $restoredAccess'},
        );
        expect(profile.statusCode, 200);
        final profileEnvelope = jsonDecode(profile.body) as Map<String, dynamic>;
        expect(profileEnvelope['ok'], isTrue);

        await client.signOut();
        expect(await client.accessToken(), isNull,
            reason: 'Sign-out must clear the persisted refresh token');
        final revokedProfile = await http.get(
          baseUri.resolve('/api/me/profile'),
          headers: {'Authorization': 'Bearer $restoredAccess'},
        );
        expect(revokedProfile.statusCode, 401,
            reason: 'The Backend must reject the access token after Flutter logout');
      } finally {
        try {
          await client.signOut();
        } catch (_) {
          await client.clearSession();
        }
        client.close();
        signedIn.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
