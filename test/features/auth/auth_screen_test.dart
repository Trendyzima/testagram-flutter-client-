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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  testWidgets('account creation stays visible while application submission remains gated',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        enableIdentityRegistration: false,
        identityApplicationStore: identityStore,
      ),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Create your account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tapVisible(tester, find.text('Create your account'));
    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Submit application'), findsNothing);
    expect(find.textContaining('Registration is currently closed'), findsOneWidget);
    expect(identityStore, isNotNull);
  });

  testWidgets('sign-in page links to account creation and recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, onSignedIn: () {}, identityApplicationStore: identityStore),
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
    expect(find.widgetWithText(FilledButton, 'Submit application'), findsOneWidget);

    await tapVisible(tester, find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tapVisible(tester, find.text('Sign in').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('registration requires private identity evidence and dual approval before account creation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(authClient: authClient, requireIdentityReview: true, onSignedIn: () {}, enableIdentityRegistration: true, identityApplicationStore: identityStore),
    ));

    // Identity review mode intentionally opens the application page directly;
    // it must not require a second tap on the sign-in-only Create account action.
    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions.'), findsOneWidget);
    expect(find.text('I accept the Privacy Notice.'), findsOneWidget);
    expect(find.textContaining('Complete identity verification and independent account approval'), findsOneWidget);

    final action = find.widgetWithText(FilledButton, 'Submit application');
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);

    // The form still validates locally before any backend request is made.
    await tapVisible(tester, action);
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Use 3–30 letters, numbers or underscores.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
  });

  testWidgets('accounts without an approved identity link are routed to identity application',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        authClient: authClient,
        onSignedIn: () {},
        requireIdentityReview: true,
        enableIdentityRegistration: true,
        identityApplicationStore: identityStore,
      ),
    ));

    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.text('Submit application'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions.'), findsOneWidget);
    expect(find.text('I accept the Privacy Notice.'), findsOneWidget);
    expect(find.textContaining('Complete identity verification and independent account approval'), findsOneWidget);
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
