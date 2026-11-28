import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/auth/native_auth_client.dart';
import 'package:testagram/features/auth/auth_legal_documents.dart';
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
  int resendCalls = 0;
  String? resentEmail;
  int verifyCalls = 0;
  String? verifiedToken;
  String? verifiedEmail;
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
  Future<void> resendVerification(String email) async {
    resendCalls++;
    resentEmail = email;
  }

  @override
  Future<void> verifyEmail(String token, {String? email}) async {
    verifyCalls++;
    verifiedToken = token;
    verifiedEmail = email;
  }

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

  testWidgets('public signup entry explains the identity approval requirement when legacy identity flag is disabled', (tester) async {
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
    expect(find.text('Create account'), findsOneWidget);
    await tapVisible(tester, find.text('Sign up'));
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(find.text('Create your Testagram account'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.textContaining('Identity verification is separate'), findsWidgets);
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
        requireIdentityReview: false,
        enableIdentityRegistration: false,
        identityApplicationStore: identityStore,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    await tapVisible(tester, find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your Testagram account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
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
    expect(find.widgetWithText(OutlinedButton, 'Create account'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    await tapVisible(tester, find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your Testagram account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);

    await tapVisible(tester, find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tapVisible(tester, find.text('Sign in').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('legacy identity entry cannot force the public identity application', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, requireIdentityReview: true, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));
    expect(find.text('Create your Testagram account'), findsOneWidget);
    expect(find.text('Submit application'), findsNothing);
    expect(find.textContaining('Identity verification is separate'), findsOneWidget);
  });

  testWidgets('verification screen lets users enter an email and resend safely', (tester) async {
    final nativeAuth = _FakeNativeAuthSession();
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: nativeAuth,
        onSignedIn: () {},
        requireVerification: true,
      ),
    ));

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Resend code and link'), findsOneWidget);

    await tapVisible(tester, find.text('Resend code and link'));
    await tester.pumpAndSettle();
    expect(nativeAuth.resendCalls, 0);
    expect(find.text('Enter your email address.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'person@example.test');
    await tapVisible(tester, find.text('Resend code and link'));
    await tester.pumpAndSettle();

    expect(nativeAuth.resendCalls, 1);
    expect(nativeAuth.resentEmail, 'person@example.test');
    expect(find.textContaining('fresh verification code and link have been sent'), findsOneWidget);
  });

  testWidgets('verification page accepts the emailed six-digit OTP', (tester) async {
    final nativeAuth = _FakeNativeAuthSession();
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: nativeAuth,
        onSignedIn: () {},
        requireVerification: true,
        initialEmail: 'person@example.test',
      ),
    ));

    expect(find.text('Six-digit email code'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '012345');
    await tapVisible(tester, find.text('Verify email'));

    expect(nativeAuth.verifyCalls, 1);
    expect(nativeAuth.verifiedToken, '012345');
    expect(nativeAuth.verifiedEmail, 'person@example.test');
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('verification page has a clear route back to sign in without unrelated tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        requireVerification: true,
      ),
    ));

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Sign up'), findsNothing);
    expect(find.text('Reset password'), findsNothing);
    expect(find.text('Back to sign in'), findsOneWidget);

    await tapVisible(tester, find.text('Back to sign in'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('identity-review entry opens the evidence-backed application form', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, requireIdentityReview: true, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));
    expect(find.text('Create your Testagram account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('I confirm that I am at least 18 years old.'), findsOneWidget);
    expect(find.textContaining('Identity verification is separate'), findsWidgets);
  });

  testWidgets('application links let applicants inspect Terms and Privacy before consent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));
    await tapVisible(tester, find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.text('Read Terms'), findsOneWidget);
    expect(find.text('Read Privacy Notice'), findsOneWidget);
    await tapVisible(tester, find.text('Read Terms'));
    expect(find.textContaining('TESTAGRAM TERMS AND CONDITIONS'), findsOneWidget);
    await tapVisible(tester, find.text('Close'));
    await tapVisible(tester, find.text('Read Privacy Notice'));
    expect(find.textContaining('TESTAGRAM PRIVACY NOTICE'), findsOneWidget);
    expect(AuthLegalDocuments.termsText, contains('TESTAGRAM TERMS AND CONDITIONS'));
    expect(AuthLegalDocuments.privacyText, contains('TESTAGRAM PRIVACY NOTICE'));
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
