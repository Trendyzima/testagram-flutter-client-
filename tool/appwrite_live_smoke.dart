import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart';

String requiredEnv(String key) {
  final value = Platform.environment[key]?.trim() ?? '';
  if (value.isEmpty) {
    throw StateError('Required staging environment value is missing: $key');
  }
  return value;
}

Future<void> main() async {
  final phase = requiredEnv('APPWRITE_AUTH_PHASE');
  final endpoint = requiredEnv('APPWRITE_STAGING_ENDPOINT');
  final projectId = requiredEnv('APPWRITE_STAGING_PROJECT_ID');
  final siteUrl = Uri.parse(requiredEnv('APPWRITE_STAGING_SITE_URL'));

  if (siteUrl.scheme != 'https' ||
      siteUrl.host.isEmpty ||
      siteUrl.userInfo.isNotEmpty ||
      siteUrl.hasQuery ||
      siteUrl.hasFragment) {
    throw StateError('APPWRITE_STAGING_SITE_URL must be a clean HTTPS origin.');
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId);
  final account = Account(client);

  switch (phase) {
    case 'register':
      final email = requiredEnv('APPWRITE_STAGING_EMAIL').toLowerCase();
      final password = requiredEnv('APPWRITE_STAGING_PASSWORD');
      final name = requiredEnv('APPWRITE_STAGING_NAME');
      final userId = ID.unique();

      await account.create(
        userId: userId,
        email: email,
        password: password,
        name: name,
      );
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      await account.createVerification(
        url: '${siteUrl.origin}/?mode=verification',
      );
      stdout.writeln(jsonEncode({
        'phase': phase,
        'result': 'verification_email_requested',
        'user_id': userId,
        'email': email,
        'next': 'Open the verification email and use its userId and secret in the protected staging workflow secrets.',
      }));
      break;

    case 'verify':
      final userId = requiredEnv('APPWRITE_VERIFICATION_USER_ID');
      final secret = requiredEnv('APPWRITE_VERIFICATION_SECRET');
      final email = requiredEnv('APPWRITE_STAGING_EMAIL').toLowerCase();
      final password = requiredEnv('APPWRITE_STAGING_PASSWORD');

      await account.updateVerification(userId: userId, secret: secret);
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final verifiedUser = await account.get();
      if (!verifiedUser.emailVerification) {
        throw StateError('Appwrite accepted the verification request but the account is still unverified.');
      }
      await account.createRecovery(
        email: email,
        url: '${siteUrl.origin}/?mode=recovery',
      );
      stdout.writeln(jsonEncode({
        'phase': phase,
        'result': 'email_verified_and_recovery_email_requested',
        'user_id': userId,
        'email_verified': verifiedUser.emailVerification,
        'next': 'Open the password recovery email and store its userId and secret in the protected staging workflow secrets.',
      }));
      break;

    case 'recover':
      final userId = requiredEnv('APPWRITE_RECOVERY_USER_ID');
      final secret = requiredEnv('APPWRITE_RECOVERY_SECRET');
      final email = requiredEnv('APPWRITE_STAGING_EMAIL').toLowerCase();
      final newPassword = requiredEnv('APPWRITE_RECOVERY_NEW_PASSWORD');

      await account.updateRecovery(
        userId: userId,
        secret: secret,
        password: newPassword,
        passwordAgain: newPassword,
      );
      await account.createEmailPasswordSession(
        email: email,
        password: newPassword,
      );
      final recoveredUser = await account.get();
      if (recoveredUser.email != email || !recoveredUser.emailVerification) {
        throw StateError('Recovery login did not return the expected verified staging account.');
      }
      stdout.writeln(jsonEncode({
        'phase': phase,
        'result': 'password_recovered_and_login_verified',
        'email_verified': recoveredUser.emailVerification,
      }));
      break;

    default:
      throw StateError('APPWRITE_AUTH_PHASE must be register, verify, or recover.');
  }
}
