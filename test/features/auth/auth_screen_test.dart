import 'package:appwrite/appwrite.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/auth/auth_screen.dart';

class _FakeAccount implements Account {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Account account;

  setUp(() {
    // These screen tests exercise local navigation and registration consent gates;
    // no Appwrite network or platform implementation should be constructed.
    account = _FakeAccount();
  });

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('registration is hidden by default when the identity UI flag is disabled',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        account: account,
        onSignedIn: () {},
        requireIdentityReview: true,
      ),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign up'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsNothing);
    expect(find.textContaining('Registration is temporarily unavailable'), findsOneWidget);
  });

  testWidgets('sign-in page links to account creation and recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}, enableIdentityRegistration: true),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('New to Testagram?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    await tapVisible(tester, find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tapVisible(tester, find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('registration requires private identity evidence and dual approval before account creation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}, enableIdentityRegistration: true),
    ));

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions.'), findsOneWidget);
    expect(find.text('I accept the Privacy Notice.'), findsOneWidget);
    expect(find.textContaining('Two independent reviewers must approve'), findsOneWidget);

    final action = find.widgetWithText(FilledButton, 'Submit identity application');
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);

    // The form still validates locally before any Appwrite request is made.
    await tapVisible(tester, action);
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Use 3–30 letters, numbers or underscores.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
  });

  testWidgets('accounts without an approved identity link are routed to identity application',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        account: account,
        onSignedIn: () {},
        requireIdentityReview: true,
        enableIdentityRegistration: true,
      ),
    ));

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Submit identity application'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions.'), findsOneWidget);
    expect(find.text('I accept the Privacy Notice.'), findsOneWidget);
    expect(find.textContaining('Complete identity verification and independent account approval'), findsOneWidget);
  });

  testWidgets('legal documents can be read before consent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}, enableIdentityRegistration: true),
    ));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Read Terms and Conditions'));
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.textContaining('TESTAGRAM TERMS AND CONDITIONS'),
        findsOneWidget);
    await tapVisible(tester, find.text('Close'));

    await tapVisible(tester, find.text('Read Privacy Notice'));
    expect(find.textContaining('TESTAGRAM PRIVACY NOTICE'), findsOneWidget);
  });

  testWidgets('forgot-password page is reachable from sign in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}, enableIdentityRegistration: true),
    ));

    await tapVisible(tester, find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });
}
