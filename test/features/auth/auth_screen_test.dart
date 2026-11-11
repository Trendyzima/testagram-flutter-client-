import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/auth/auth_screen.dart';

void main() {
  late Account account;

  setUp(() {
    final client = Client()
      ..setEndpoint('https://cloud.appwrite.io/v1')
      ..setProject('testagram-widget-test');
    account = Account(client);
  });

  testWidgets('sign-in page links to account creation and recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create a new account'), findsOneWidget);
  });

  testWidgets('account creation requires profile fields, age and legal consent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('I confirm that I am 18 years old or above.'), findsOneWidget);
    expect(find.text('I accept the Terms and Conditions and Privacy Notice.'),
        findsOneWidget);
    expect(find.text('Read Terms and Conditions'), findsOneWidget);
    expect(find.text('Read Privacy Notice'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
  });

  testWidgets('registration remains fail-closed until identity approval exists',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test_user');
    await tester.enterText(fields.at(2), 'test@example.com');
    await tester.enterText(fields.at(3), 'ValidPass123');
    await tester.enterText(fields.at(4), 'ValidPass123');

    await tester.tap(find.text('I confirm that I am 18 years old or above.'));
    await tester.tap(find.text(
        'I accept the Terms and Conditions and Privacy Notice.'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no account has been created'), findsOneWidget);
  });

  testWidgets('forgot-password page is reachable from sign in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });
}
