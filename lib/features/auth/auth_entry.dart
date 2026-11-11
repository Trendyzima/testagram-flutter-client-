enum AuthEntryMode { signIn, signUp, forgotPassword, verifyEmail, resetPassword }

class AuthEntry {
  const AuthEntry({
    required this.mode,
    required this.isExplicit,
    this.userId,
    this.secret,
  });

  final AuthEntryMode mode;
  final bool isExplicit;
  final String? userId;
  final String? secret;

  bool get hasCompleteCallback =>
      userId != null && userId!.isNotEmpty && secret != null && secret!.isNotEmpty;

  factory AuthEntry.fromUri(Uri uri) {
    final query = uri.queryParameters;
    final rawMode = query['mode'];
    final mode = switch (rawMode) {
      'signup' || 'sign-up' => AuthEntryMode.signUp,
      'forgot' => AuthEntryMode.forgotPassword,
      'reset' || 'recovery' => AuthEntryMode.resetPassword,
      'verification' => AuthEntryMode.verifyEmail,
      'signin' || 'sign-in' => AuthEntryMode.signIn,
      _ => AuthEntryMode.signIn,
    };
    return AuthEntry(
      mode: mode,
      isExplicit: const {
        'signup', 'sign-up', 'forgot', 'reset', 'recovery',
        'verification', 'signin', 'sign-in',
      }.contains(rawMode),
      userId: query['userId'],
      secret: query['secret'],
    );
  }
}
