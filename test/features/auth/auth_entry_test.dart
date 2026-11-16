import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/auth/auth_entry.dart';

void main() {
  group('AuthEntry', () {
    test('supports direct sign-in and account-creation entry URLs', () {
      expect(
        AuthEntry.fromUri(Uri.parse('https://testagram.site/?mode=signin')).mode,
        AuthEntryMode.signIn,
      );
      final signUp = AuthEntry.fromUri(
        Uri.parse('https://testagram.site/?mode=signup'),
      );
      expect(signUp.mode, AuthEntryMode.signUp);
      expect(signUp.isExplicit, isTrue);
    });

    test('supports forgot-password and recovery callbacks', () {
      expect(
        AuthEntry.fromUri(Uri.parse('https://testagram.site/?mode=forgot')).mode,
        AuthEntryMode.forgotPassword,
      );
      final reset = AuthEntry.fromUri(Uri.parse(
        'https://testagram.site/reset-password?token=one-time',
      ));
      expect(reset.mode, AuthEntryMode.resetPassword);
      expect(reset.token, 'one-time');
      expect(reset.hasCompleteCallback, isTrue);
    });

    test('recognizes email-verification callbacks', () {
      final entry = AuthEntry.fromUri(Uri.parse(
        'https://testagram.site/verify-email?application_id=11111111-1111-4111-8111-111111111111&token=verify',
      ));
      expect(entry.mode, AuthEntryMode.verifyEmail);
      expect(entry.applicationId, '11111111-1111-4111-8111-111111111111');
      expect(entry.token, 'verify');
      expect(entry.hasCompleteCallback, isTrue);
    });
  });
}
