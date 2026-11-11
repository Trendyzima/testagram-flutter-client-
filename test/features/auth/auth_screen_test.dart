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

  testWidgets('authentication offers sign-in, registration and recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('registration validates fields and remains fail-closed',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(account: account, onSignedIn: () {}),
    ));

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));

    await tester.tap(find.text('Continue securely'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your display name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test_user');
    await tester.enterText(fields.at(2), 'test@example.com');
    await tester.enterText(fields.at(3), 'ValidPass123');

    final checkboxes = find.byType(CheckboxListTile);
    expect(checkboxes, findsNWidgets(2));
    await tester.tap(checkboxes.at(0));
    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue securely'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Registration is not open yet'),
      findsOneWidget,
    );
    expect(
      find.textContaining('no account has been created'),
      findsOneWidget,
    );
  });
}
