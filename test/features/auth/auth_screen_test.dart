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

  testWidgets('sign-in page links to account creation and recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
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

  testWidgets('self-service registration is enabled without identity-review gate',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions.'), findsOneWidget);
    expect(find.text('I accept the Privacy Notice.'), findsOneWidget);
    expect(find.text('Create your Testagram account'), findsOneWidget);

    final action = find.widgetWithText(FilledButton, 'Create account');
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);

    // The form still validates locally before any Appwrite request is made.
    await tapVisible(tester, action);
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
  });

  testWidgets('restored verified accounts can complete Backend registration consent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        account: account,
        onSignedIn: () {},
        requireRegistrationConsent: true,
      ),
    ));

    expect(find.text('Finish setting up your account'), findsOneWidget);
    expect(find.text('Accept and continue'), findsOneWidget);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions.'), findsOneWidget);
    expect(find.text('I accept the Privacy Notice.'), findsOneWidget);
    expect(find.text('This step records your current declarations with Testagram.'), findsOneWidget);
  });

  testWidgets('legal documents can be read before consent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
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
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    await tapVisible(tester, find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });
}
