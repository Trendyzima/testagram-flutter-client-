import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:testagram/app.dart';
import 'package:testagram/core/app_config.dart';
import 'package:testagram/core/auth/native_auth_client.dart';

class _MemoryNativeAuthStorage implements NativeAuthStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  testWidgets('starts at Testagram-owned sign in without an Appwrite dependency',
      (tester) async {
    var unexpectedRequests = 0;
    final authClient = NativeAuthClient(
      baseUri: AppConfig.backendOrigin,
      storage: _MemoryNativeAuthStorage(),
      httpClient: MockClient((request) async {
        unexpectedRequests++;
        throw StateError('No network request is expected without a saved session.');
      }),
    );
    addTearDown(authClient.close);

    await tester.pumpWidget(TestagramApp(authClient: authClient));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Appwrite'), findsNothing);
    expect(unexpectedRequests, 0);
  });
}
