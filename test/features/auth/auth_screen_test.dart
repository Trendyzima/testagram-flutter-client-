import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _FakeNativeAuthSession implements NativeAuthSession {
  int signUpCalls = 0;
  String? signedUpEmail;
  String? signedUpUsername;
  String? signedUpPassword;

  @override
  Future<void> signUp({required String email, required String username, required String password}) async {
    signUpCalls++;
    signedUpEmail = email;
    signedUpUsername = username;
    signedUpPassword = password;
  }

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> verifyEmail(String token) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecoveryReadyNativeAuthSession extends _FakeNativeAuthSession {
  int attempts = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    attempts += 1;
    lastEmail = email;
    lastPassword = password;
    if (attempts == 1) {
      throw const NativeAuthException(
        'Testagram is awake and its application database is ready. Retry sign-in to continue.',
        statusCode: 503,
        code: 'API_ORIGIN_RETRY_READY',
      );
    }
    throw const NativeAuthException(
      'The explicit retry reached the authentication client.',
      code: 'TEST_EXPLICIT_RETRY_REACHED',
    );
  }
}

void main() {
  late NativeAuthSession authClient;
  late IdentityApplicationStore identityStore;

  setUp(() {
    // These screen tests exercise local navigation and registration consent gates;
    // no network or platform implementation should be constructed.
    authClient = _FakeNativeAuthSession();
    identityStore = IdentityApplicationStore(storage: _MemoryIdentityStorage());
  });

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('keeps login form intent after verified VPS recovery and allows explicit retry',
      (tester) async {
    final recoveryAuth = _RecoveryReadyNativeAuthSession();
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: recoveryAuth,
        onSignedIn: () {},
        enableIdentityRegistration: false,
        identityApplicationStore: identityStore,
      ),
    ));

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    final email = fields.at(0);
    final password = fields.at(1);
    expect(email, findsOneWidget);
    expect(password, findsOneWidget);

    await tester.enterText(email, 'person@example.test');
    await tester.enterText(password, 'correct-password-123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));

    expect(find.textContaining('Your sign-in details are still here'), findsOneWidget);
    expect(tester.widget<TextFormField>(email).controller?.text, 'person@example.test');
    expect(tester.widget<TextFormField>(password).controller?.text, 'correct-password-123');
    expect(recoveryAuth.attempts, 1);
    expect(recoveryAuth.lastEmail, 'person@example.test');
    expect(recoveryAuth.lastPassword, 'correct-password-123');

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    expect(recoveryAuth.attempts, 2);
    expect(recoveryAuth.lastEmail, 'person@example.test');
    expect(recoveryAuth.lastPassword, 'correct-password-123');
  });

  testWidgets('native account creation remains available when legacy identity flag is disabled', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        enableIdentityRegistration: false,
        identityApplicationStore: identityStore,
      ),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('NEW HERE?'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Submit application'), findsNothing);
    await tapVisible(tester, find.text('Sign up'));
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('native signup does not restore an old identity application',
      (tester) async {
    final draft = IdentityApplicationDraft(
      email: 'saved-applicant@example.test',
      username: 'saved_applicant',
      displayName: 'Saved Applicant',
      idempotencyKey: List.filled(43, 'a').join(),
      createdAt: DateTime.utc(2026, 11, 20),
    );
    await identityStore.save(draft);

    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        requireIdentityReview: true,
        enableIdentityRegistration: false,
        identityApplicationStore: identityStore,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Submit application'), findsNothing);
    expect(find.text('saved-applicant@example.test'), findsNothing);
    // Preserve the user's encrypted draft for a future, deliberate reopening.
    expect((await identityStore.load())?.email, 'saved-applicant@example.test');
  });

  testWidgets('sign-in page links to account creation and recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('NEW HERE?'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Create your account'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    await tapVisible(tester, find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);

    await tapVisible(tester, find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tapVisible(tester, find.text('Sign in').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('ordinary signup calls native auth and needs no admin review', (tester) async {
    final nativeAuth = _FakeNativeAuthSession();
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: nativeAuth, requireIdentityReview: true, onSignedIn: () {}, enableIdentityRegistration: false, identityApplicationStore: identityStore),
    ));

    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Create password'), findsOneWidget);
    expect(find.textContaining('no administrator approval is required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'native_user');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'native@example.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Create password'), 'native-password-123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));

    expect(nativeAuth.signUpCalls, 1);
    expect(nativeAuth.signedUpEmail, 'native@example.test');
    expect(nativeAuth.signedUpUsername, 'native_user');
    expect(nativeAuth.signedUpPassword, 'native-password-123');
    expect(find.textContaining('Check your email'), findsOneWidget);
    expect(find.text('Submit application'), findsNothing);
  });

  testWidgets('signup entry opens native account creation instead of identity application', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, requireIdentityReview: true, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));
    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Submit application'), findsNothing);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Create password'), findsOneWidget);
    expect(find.textContaining('no administrator approval is required'), findsOneWidget);
  });

  testWidgets('legal documents can be read before consent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, requireIdentityReview: true, onSignedIn: () {}, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));
    // Identity review mode opens the gated application page directly.
    await tapVisible(tester, find.text('Read terms'));
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.textContaining('TESTAGRAM TERMS AND CONDITIONS'),
        findsOneWidget);
    await tapVisible(tester, find.text('Close'));

    await tapVisible(tester, find.text('Read privacy notice'));
    expect(find.textContaining('TESTAGRAM PRIVACY NOTICE'), findsOneWidget);
  });

  testWidgets('forgot-password page is reachable from sign in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));

    await tapVisible(tester, find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });
  testWidgets('mobile authentication uses the new branded hero and uncluttered form layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        enableIdentityRegistration: true,
        identityApplicationStore: identityStore,
      ),
    ));

    expect(find.text('More than a feed.\nA world of voices.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Your voice'), findsOneWidget);
    expect(find.text('Open conversations'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
  });

  testWidgets('wide authentication retains the two-column branded experience',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        enableIdentityRegistration: true,
        identityApplicationStore: identityStore,
      ),
    ));

    expect(find.text('More than a feed.\nA world of voices.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

}
