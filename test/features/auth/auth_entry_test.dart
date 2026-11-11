import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/auth/auth_entry.dart';

void main() {
  group('AuthEntry', () {
    test('supports direct sign-in and sign-up entry URLs', () {
      final signIn = AuthEntry.fromUri(Uri.parse('https://testagram.site/?mode=signin'));
      final signUp = AuthEntry.fromUri(Uri.parse('https://testagram.site/?mode=signup'));

      expect(signIn.mode, AuthEntryMode.signIn);
      expect(signIn.isExplicit, isTrue);
      expect(signUp.mode, AuthEntryMode.signUp);
      expect(signUp.isExplicit, isTrue);
    });

    test('supports forgot-password entry and recovery callback', () {
      final forgot = AuthEntry.fromUri(Uri.parse('https://testagram.site/?mode=forgot'));
      final recovery = AuthEntry.fromUri(Uri.parse(
        'https://testagram.site/?mode=recovery&userId=user_123&secret=one-time-secret',
      ));

      expect(forgot.mode, AuthEntryMode.forgotPassword);
      expect(recovery.mode, AuthEntryMode.resetPassword);
      expect(recovery.hasCompleteCallback, isTrue);
      expect(recovery.userId, 'user_123');
      expect(recovery.secret, 'one-time-secret');
    });

    test('recognizes verification callbacks and rejects incomplete callback data', () {
      final complete = AuthEntry.fromUri(Uri.parse(
        'https://testagram.site/?mode=verification&userId=user_123&secret=verification-secret',
      ));
      final incomplete = AuthEntry.fromUri(Uri.parse(
        'https://testagram.site/?mode=verification&userId=user_123',
      ));

      expect(complete.mode, AuthEntryMode.verifyEmail);
      expect(complete.hasCompleteCallback, isTrue);
      expect(incomplete.mode, AuthEntryMode.verifyEmail);
      expect(incomplete.hasCompleteCallback, isFalse);
      expect(incomplete.isExplicit, isTrue);
    });

    test('ordinary application URLs do not force the authentication gate', () {
      final entry = AuthEntry.fromUri(Uri.parse('https://testagram.site/'));

      expect(entry.mode, AuthEntryMode.signIn);
      expect(entry.isExplicit, isFalse);
      expect(entry.hasCompleteCallback, isFalse);
    });
  });
}
